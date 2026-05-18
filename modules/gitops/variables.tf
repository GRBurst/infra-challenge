variable "environment" {
  type        = string
  description = "Environment in {local, dev, prod}. Selects values-<environment>.yaml."
  validation {
    condition     = contains(["local", "dev", "prod"], var.environment)
    error_message = "environment must be one of local, dev, prod."
  }
}

variable "repo_url" {
  type        = string
  description = "Git repository URL ArgoCD pulls from."
}

variable "target_revision" {
  type        = string
  description = "Git ref (branch/tag/commit) ArgoCD tracks."
  default     = "HEAD"
}

variable "greeter_chart_path" {
  type    = string
  default = "charts/greeter"
}

variable "argocd_chart_version" {
  type    = string
  default = "9.5.14"
}

variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "greeter_namespace" {
  type    = string
  default = "greeter"
}
