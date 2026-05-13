variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

variable "kubeconfig_context" {
  type    = string
  default = "k3d-infra-challenge"
}

variable "gitea_enabled" {
  type        = bool
  description = "Deploy in-cluster Gitea and point ArgoCD at it instead of GitHub."
  default     = false
}

variable "greeter_branch" {
  type        = string
  description = "Branch ArgoCD tracks. Required when gitea_enabled=true."
  default     = ""
}
