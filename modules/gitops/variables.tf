variable "environment" {
  type        = string
  description = "Environment in {local, dev, prod}. Selects values-<environment>.yaml."
  validation {
    condition     = contains(["local", "dev", "prod"], var.environment)
    error_message = "environment must be one of local, dev, prod."
  }
}

variable "greeter_repo_url" {
  type    = string
  default = "https://github.com/GRBurst/infra-challenge.git"
}

variable "greeter_chart_path" {
  type    = string
  default = "charts/greeter"
}

variable "greeter_target_revision" {
  type    = string
  default = "HEAD"
}

variable "argocd_chart_version" {
  type    = string
  default = "7.7.0"
}

variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "greeter_namespace" {
  type    = string
  default = "greeter"
}
