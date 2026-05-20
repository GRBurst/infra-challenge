variable "namespace" {
  type        = string
  description = "Kubernetes namespace for Gitea."
  default     = "gitea"
}

variable "chart_version" {
  type        = string
  description = "Pinned upstream Gitea Helm chart version (https://dl.gitea.com/charts/)."
}

variable "service_port" {
  type        = number
  description = "In-cluster gitea-http service port (must match service.http.port in values)."
  default     = 3000
}

variable "host_port" {
  type        = number
  description = "Host-side port mapped by k3d to the gitea NodePort (used in push/web URLs)."
  default     = 3000
}

# Note: gitea admin credentials are intentionally NOT exposed as variables.
# They are hardcoded to gitea-admin / gitea-admin in values.yaml and in the
# push_url output. This module is local-only (k3d demo). Never deploy to a
# real cluster.

variable "repo_name" {
  type        = string
  description = "Repository name created in Gitea under admin_user."
  default     = "infra-challenge"
}

variable "helm_timeout_seconds" {
  type        = number
  description = "Timeout for the Helm release."
  default     = 300
}
