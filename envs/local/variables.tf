variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

variable "kubeconfig_context" {
  type    = string
  default = "k3d-infra-challenge"
}

variable "greeter_branch" {
  type        = string
  description = "Branch ArgoCD tracks (also the branch force-pushed to Gitea)."
  validation {
    condition     = length(var.greeter_branch) > 0
    error_message = "greeter_branch must be a non-empty branch name."
  }
}

variable "gitea_chart_version" {
  type        = string
  description = "Pinned Gitea Helm chart version."
  default     = "11.0.1"
}
