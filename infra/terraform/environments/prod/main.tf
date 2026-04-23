data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = "10.0.0.0/16"

  azs              = local.azs
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets  = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  database_subnets = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

  enable_nat_gateway         = true
  single_nat_gateway         = false
  one_nat_gateway_per_az     = true
  enable_dns_hostnames       = true
  enable_dns_support         = true
  create_database_subnet_group = true
  database_subnet_group_name   = "${var.project_name}-${var.environment}-db-subnet-group"

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.1"

  cluster_name    = var.cluster_name
  cluster_version = "1.33"

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  eks_managed_node_groups = {
    app = {
      instance_types = ["t3.large"]
      min_size       = 3
      max_size       = 6
      desired_size   = 3
      subnet_ids     = module.vpc.private_subnets
      ami_type       = "AL2023_x86_64_STANDARD"
      capacity_type  = "ON_DEMAND"

      labels = {
        workload = "app"
      }
    }
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "RDS SG"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Postgres from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier                  = "${var.project_name}-${var.environment}-postgres"
  allocated_storage           = 50
  max_allocated_storage       = 200
  engine                      = "postgres"
  engine_version              = "17.4"
  instance_class              = "db.t4g.micro"
  db_name                     = "homeservice"
  username                    = "hsadmin"
  manage_master_user_password = true
  multi_az                    = true
  publicly_accessible         = false
  storage_encrypted           = true
  backup_retention_period     = 7
  deletion_protection         = true
  skip_final_snapshot         = false
  db_subnet_group_name        = module.vpc.database_subnet_group
  vpc_security_group_ids      = [aws_security_group.rds.id]
}

resource "aws_ecr_repository" "frontend" {
  name                 = "home-service/frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
}

resource "aws_ecr_repository" "user_service" {
  name                 = "home-service/user-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
}

resource "aws_ecr_repository" "booking_service" {
  name                 = "home-service/booking-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
}

resource "aws_ecr_repository" "worker_service" {
  name                 = "home-service/worker-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
}

data "aws_route53_zone" "public" {
  name         = var.public_hosted_zone_name
  private_zone = false
}

resource "aws_acm_certificate" "frontend" {
  domain_name       = "app.${var.domain_name}"
  validation_method = "DNS"
}

resource "aws_route53_record" "frontend_validation" {
  for_each = {
    for dvo in aws_acm_certificate.frontend.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      value  = dvo.resource_record_value
      type   = dvo.resource_record_type
      zoneid = data.aws_route53_zone.public.zone_id
    }
  }

  zone_id = each.value.zoneid
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "frontend" {
  certificate_arn         = aws_acm_certificate.frontend.arn
  validation_record_fqdns = [for record in aws_route53_record.frontend_validation : record.fqdn]
}

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-${var.environment}-frontend-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "OAC for frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = ["app.${var.domain_name}"]

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "frontendS3"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    target_origin_id       = "frontendS3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.frontend.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

data "aws_iam_policy_document" "frontend_bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_bucket.json
}
