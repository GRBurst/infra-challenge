variable "namespace" {
  type        = string
  description = "Org abbreviation (e.g. 'hm')."
}

variable "environment" {
  type        = string
  description = "Environment name."
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of dev, prod."
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_group_min_size" {
  type    = number
  default = 1
}

variable "node_group_max_size" {
  type    = number
  default = 3
}

variable "node_group_desired_size" {
  type    = number
  default = 2
}

variable "cluster_endpoint_public_access" {
  type        = bool
  default     = true
  description = <<-EOT
    Whether the EKS public API endpoint is reachable from the internet.
    Dev tradeoff: true to permit kubectl/CI from anywhere. For prod, set
    to false or restrict via cluster_endpoint_public_access_cidrs.
  EOT
}

variable "cluster_endpoint_public_access_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDR allowlist when cluster_endpoint_public_access = true."
}

variable "create" {
  type        = bool
  default     = true
  description = "Whether to create platform resources. Set to false to skip AWS resource creation (useful for offline testing)."
}

variable "cluster_admin_arns" {
  type        = list(string)
  default     = []
  description = "IAM ARNs allowed to assume the cluster-admin role. Stable across re-applies."
}
