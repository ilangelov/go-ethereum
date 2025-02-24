provider "aws" {
  region = "us-west-2"  # Change to your desired AWS region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "aws_iam_role" "eks_cluster_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_subnet" "subnet" {
  count = 2
  cidr_block = "10.0.${count.index}.0/24"
  vpc_id     = aws_vpc.vpc.id
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "my-cluster"
  cluster_version = "1.21"
  
  vpc_id          = aws_vpc.vpc.id
  subnet_ids      = [for subnet in aws_subnet.subnet : subnet.id]

  # For node groups, use `node_groups` like below:
  node_groups = {
    eks_nodes = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1
      instance_type    = "t3.medium"
      key_name         = "your-ec2-key-pair" # Replace with your EC2 key pair
      subnet_ids       = [for subnet in aws_subnet.subnet : subnet.id] # Specify subnets for worker nodes
    }
  }

  # Optional: enabling IAM roles for Kubernetes worker nodes
  manage_aws_auth = true  # Optional if you need to manage the AWS auth
}
