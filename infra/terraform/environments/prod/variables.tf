variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "home-service"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "domain_name" {
  type = string
}

variable "public_hosted_zone_name" {
  type = string
}

variable "cluster_name" {
  type    = string
  default = "home-service-prod"
}
