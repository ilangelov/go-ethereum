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

resource "aws_iam_role" "eks_cluster_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = { Service = "eks.amazonaws.com" }
        Effect    = "Allow"
        Sid       = ""
      },
    ]
  })
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 18.0"  # Ensure you're using a version that supports these arguments
  cluster_name    = "my-cluster"
  cluster_version = "1.21"
  
  vpc_id          = aws_vpc.vpc.id
  subnet_ids      = [for subnet in aws_subnet.subnet : subnet.id]

  # Node Group Configuration (Managed node groups will need different syntax or version support)
  node_groups = {
    eks_nodes = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1
      instance_type    = "t3.medium"
      key_name         = "your-ec2-key-pair"  # Replace with your EC2 key pair
      subnet_ids       = [for subnet in aws_subnet.subnet : subnet.id]
    }
  }
}

# Manually create the aws-auth ConfigMap if the "manage_aws_auth" option doesn't work
resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = <<EOT
    - rolearn: arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eks-cluster-role
      username: eks-admin
      groups:
        - system:masters
    EOT
  }
}

data "aws_caller_identity" "current" {}
