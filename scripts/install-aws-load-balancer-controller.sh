#!/bin/bash
set -e

CLUSTER_NAME=home-service-prod
AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy   --policy-name AWSLoadBalancerControllerIAMPolicy   --policy-document file://iam_policy.json || true

eksctl create iamserviceaccount   --cluster=$CLUSTER_NAME   --namespace=kube-system   --name=aws-load-balancer-controller   --role-name AmazonEKSLoadBalancerControllerRole   --attach-policy-arn=arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy   --approve   --region=$AWS_REGION || true

helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm install aws-load-balancer-controller eks/aws-load-balancer-controller   -n kube-system   --set clusterName=$CLUSTER_NAME   --set serviceAccount.create=false   --set serviceAccount.name=aws-load-balancer-controller   --set region=$AWS_REGION   --set vpcId=$VPC_ID
