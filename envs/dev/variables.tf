variable "create_platform" {
  type        = bool
  default     = true
  description = "Whether to create platform resources (EKS, VPC, ECR). Set to false for offline testing."
}

variable "namespace" {
  type        = string
  description = "Organization abbreviation."
  default     = "hm"
}

variable "github_repo" {
  type        = string
  description = "GitHub repo in 'owner/name' form."
  default     = "GRBurst/infra-challenge"
}

variable "cluster_admin_arns" {
  type        = list(string)
  description = "IAM principals granted cluster-admin via EKS access entries. Required - set in terraform.tfvars or via TF_VAR_cluster_admin_arns."
  validation {
    condition = alltrue([
      for a in var.cluster_admin_arns :
      can(regex("^arn:aws:iam::[0-9]{12}:(role|user)/", a))
    ])
    error_message = "Each ARN must be a valid IAM role or user ARN."
  }
}

variable "console_admin_arns" {
  type        = list(string)
  description = "IAM principals allowed to assume the EKS console-admin role."
  default     = []
  validation {
    condition = alltrue([
      for a in var.console_admin_arns :
      can(regex("^arn:aws:iam::[0-9]{12}:(role|user)/", a))
    ])
    error_message = "Each ARN must be a valid IAM role or user ARN."
  }
}

variable "target_revision" {
  type        = string
  description = "Git ref ArgoCD tracks for the dev environment."
  default     = "challenge"
}
