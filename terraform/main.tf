# Fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

# Fetch the subnets in the VPC
data "aws_subnet" "filtered" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# EKS Cluster Module
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "go-ethereum-cluster"
  cluster_version = "1.28"  # Latest stable version
  vpc_id          = data.aws_vpc.default.id
  subnet_ids      = [for s in data.aws_subnet.filtered : s.id]  # Use only supported AZs

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.micro"]  # Free-tier instance type
      desired_capacity = 1           # Minimal nodes for demo
      min_size = 1
      max_size = 2
    }
  }
}

# Fetch EKS authentication
data "aws_eks_cluster_auth" "go_ethereum" {
  name = module.eks.cluster_name  # Reference the cluster name from the EKS module
}

# Kubernetes Provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.go_ethereum.token
}

# Kubernetes Deployment for go-ethereum
resource "kubernetes_deployment" "go_ethereum" {
  metadata {
    name = "go-ethereum-deployment"
  }

  spec {
    replicas = 1  # Keep only 1 pod for free-tier
    selector {
      match_labels = {
        app = "go-ethereum"
      }
    }

    template {
      metadata {
        labels = {
          app = "go-ethereum"
        }
      }

      spec {
        container {
          name  = "go-ethereum"
          image = "ipangelov/go-ethereum:latest"
          port {
            container_port = 30303
          }
        }
      }
    }
  }
}

# Kubernetes Service to expose go-ethereum deployment externally
resource "kubernetes_service" "go_ethereum" {
  metadata {
    name = "go-ethereum-service"
  }

  spec {
    selector = {
      app = "go-ethereum"
    }

    port {
      port        = 30303
      target_port = 30303
    }

    type = "LoadBalancer"
  }
}

# Fetch the EKS cluster details for authentication
data "aws_eks_cluster" "go_ethereum" {
  name = module.eks.cluster_name
}

# Define AWS provider to use environment variables for access
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
