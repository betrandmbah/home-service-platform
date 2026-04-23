# Home Service Platform on AWS

This repo is the actual starter layout for a production-style deployment of a home-service app on AWS using Terraform, EKS, Jenkins, Ansible, Docker/ECR, RDS PostgreSQL, Route 53, CloudFront, and Cloudflare.

## How many AWS instances/resources to use

### EC2 instances
1. **1 Jenkins EC2 instance**
   - Instance type: `t3.medium`
   - OS: Amazon Linux 2023
   - Public subnet
   - Public IP: yes
   - Purpose: Jenkins controller only

2. **EKS worker nodes**
   - Managed node group
   - Desired: `3`
   - Min: `3`
   - Max: `6`
   - Instance type: `t3.large`
   - Private subnets only
   - Purpose: frontend, user-service, booking-service, worker-service, ingress controller

### Database
3. **1 RDS PostgreSQL instance**
   - Class: `db.t4g.micro`
   - Private DB subnets
   - Multi-AZ enabled

### Networking
4. **1 VPC**
5. **3 public subnets**
6. **3 private app subnets**
7. **3 private DB subnets**
8. **3 NAT gateways** (1 per AZ)
9. **1 Internet Gateway**
10. **1 Application Load Balancer** created by Kubernetes Ingress

### Container registry
11. **4 ECR repositories**
   - frontend
   - user-service
   - booking-service
   - worker-service

## Which files go where

### On your laptop
Keep the entire repo on your laptop first and push it to GitHub.

### On Jenkins EC2 instance
Only these run there:
- Jenkins
- Docker
- AWS CLI
- kubectl
- helm
- terraform
- ansible
- git

Jenkins pulls this repo from GitHub during pipeline runs.

### On EKS worker nodes
Nothing is manually uploaded. Jenkins builds Docker images and pushes them to ECR. Kubernetes then pulls those images.

### On RDS
No files are uploaded manually. Your app connects to RDS using secrets from AWS Secrets Manager.

## Exact order to do this from start to finish

1. Create GitHub repo and push this code
2. Create Terraform backend S3 bucket and DynamoDB table
3. Create Jenkins EC2 instance
4. Run Ansible to install Jenkins and tools
5. Configure Jenkins credentials
6. Run Terraform to create VPC, EKS, ECR, RDS, Route 53, CloudFront
7. Install AWS Load Balancer Controller and metrics-server in EKS
8. Create Secrets Manager secrets
9. Run Jenkins pipeline
10. Point DNS:
   - `app.YOUR_DOMAIN` -> CloudFront
   - `api.YOUR_DOMAIN` -> ALB DNS name

## What you must change before running

Search and replace these values in the repo:
- `YOUR_DOMAIN`
- `YOUR_PUBLIC_HOSTED_ZONE_NAME`
- `YOUR_AWS_ACCOUNT_ID`
- `YOUR_GITHUB_REPO_URL`
- `YOUR_JENKINS_PUBLIC_IP`
- `YOUR_STATE_BUCKET_NAME`
