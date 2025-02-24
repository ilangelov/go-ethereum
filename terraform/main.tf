provider "aws" {
  region = "us-west-2"  # Set your desired AWS region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet" {
  count = 2
  cidr_block = "10.0.${count.index}.0/24"
  vpc_id     = aws_vpc.vpc.id
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 18.0"  # Ensure you're using a version that supports these arguments
  cluster_name    = "my-cluster"
  cluster_version = "1.21"

  vpc_id          = aws_vpc.vpc.id
  subnet_ids      = [for subnet in aws_subnet.subnet : subnet.id]

  # Optional: Skip node_groups for now if it's causing issues
  # node_groups = {}  # Skip for now
}

module "self_managed_node_group" {
  source            = "terraform-aws-modules/eks/aws//modules/self-managed-node-group"
  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  node_group_name   = "self-managed-node-group"
  node_role_arn     = aws_iam_role.eks_node_role.arn
  subnet_ids        = [for subnet in aws_subnet.subnet : subnet.id]

  instance_type     = "t3.medium"
  desired_capacity  = 2
  max_capacity      = 3
  min_capacity      = 1

  # Optional: SSH key for accessing instances
  key_name          = "your-ec2-key-pair"  # Replace with your EC2 key pair
}

resource "aws_iam_role" "eks_node_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = { Service = "ec2.amazonaws.com" }
        Effect    = "Allow"
        Sid       = ""
      },
    ]
  })
}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = <<EOT
    - rolearn: arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eks-node-role
      username: eks-node
      groups:
        - system:masters
    EOT
  }
}

data "aws_caller_identity" "current" {}
