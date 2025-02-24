resource "kubernetes_manifest" "go_ethereum_deployment" {
  manifest = yamldecode(file("${path.module}/kubernetes-deployment.yaml"))
}
