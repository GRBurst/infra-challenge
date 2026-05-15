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
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "greeter"
      namespace = var.argocd_namespace
    }
    spec = {
      sourceRepos = [var.greeter_repo_url]
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
        repoURL        = var.greeter_repo_url
        targetRevision = var.greeter_target_revision
        path           = var.greeter_chart_path
        helm           = { valueFiles = [local.values_file] }
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
