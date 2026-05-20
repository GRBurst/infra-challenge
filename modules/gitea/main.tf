resource "kubernetes_namespace_v1" "gitea" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "gitea" {
  name             = "gitea"
  repository       = "https://dl.gitea.com/charts/"
  chart            = "gitea"
  version          = var.chart_version
  namespace        = kubernetes_namespace_v1.gitea.metadata[0].name
  create_namespace = false
  timeout          = var.helm_timeout_seconds
  # values.yaml pins the admin credentials to gitea-admin / gitea-admin.
  # Hardcoded by design: this module is local-only (k3d demo). The chart's
  # default password is random, which would break seed-gitea-repo.sh basic-auth.
  values = [file("${path.module}/values.yaml")]
}
