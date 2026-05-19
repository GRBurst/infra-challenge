locals {
  values_file = "values-${var.environment}.yaml"
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true
  values = [yamlencode({
    server = {
      extraArgs = ["--insecure"]
      service   = { type = "ClusterIP" }
    }
    dex            = { enabled = false }
    applicationSet = { enabled = false }
    notifications  = { enabled = false }
  })]
}

resource "kubernetes_manifest" "appproject" {
  count = var.create_apps ? 1 : 0
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "greeter"
      namespace = var.argocd_namespace
    }
    spec = {
      sourceRepos = [var.repo_url]
      destinations = [{
        namespace = var.greeter_namespace
        server    = "https://kubernetes.default.svc"
      }]
      clusterResourceWhitelist   = [{ group = "", kind = "Namespace" }]
      namespaceResourceWhitelist = [{ group = "*", kind = "*" }]
    }
  }
  depends_on = [helm_release.argocd]
}

resource "kubernetes_manifest" "application" {
  count = var.create_apps ? 1 : 0
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "greeter"
      namespace = var.argocd_namespace
    }
    spec = {
      project = "greeter"
      source = {
        repoURL        = var.repo_url
        targetRevision = var.target_revision
        path           = var.greeter_chart_path
        helm = {
          valueFiles = [local.values_file]
          parameters = var.environment == "local" ? [
            { name = "helloTag", value = "$ARGOCD_APP_REVISION" }
          ] : []
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.greeter_namespace
      }
      syncPolicy = {
        automated   = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
  depends_on = [kubernetes_manifest.appproject]
}

moved {
  from = kubernetes_manifest.appproject
  to   = kubernetes_manifest.appproject[0]
}

moved {
  from = kubernetes_manifest.application
  to   = kubernetes_manifest.application[0]
}
