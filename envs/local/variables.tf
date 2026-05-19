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
  default     = "12.6.0"
}

variable "greeter_host_port" {
  type        = number
  description = "Host port mapped by k3d loadbalancer to the Traefik ingress (greeter)."
  default     = 8081
}

variable "argocd_host_port" {
  type        = number
  description = "Local port used in the ArgoCD port-forward hint."
  default     = 8080
}
