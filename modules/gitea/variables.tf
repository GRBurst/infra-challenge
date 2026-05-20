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

variable "admin_user" {
  type        = string
  description = "Gitea admin username. Mirrors gitea.admin.username in values."
  default     = "gitea-admin"
}

variable "admin_password" {
  type        = string
  description = "Gitea admin password. Mirrors gitea.admin.password in values."
  default     = "gitea-admin"
  sensitive   = true
}

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
