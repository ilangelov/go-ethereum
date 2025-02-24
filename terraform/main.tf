provider "aws" {
  region = "us-east-1"
}

resource "aws_eks_cluster" "devnet" {
  name     = "go-ethereum-devnet"
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    subnet_ids = aws_subnet.devnet[*].id
  }
}

resource "kubernetes_deployment" "devnet" {
  metadata {
    name = "go-ethereum"
    namespace = "default"
  }

  spec {
    replicas = 1

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
          image = "ipangelov/go-ethereum:deployed"
          name  = "go-ethereum"
          ports {
            container_port = 8545
          }
        }
      }
    }
  }
}
