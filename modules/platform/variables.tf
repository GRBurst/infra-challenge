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
  description = <<-EOT
    When false, skips all EKS / ECR / VPC-derived AWS resource creation. Used by
    OpenTofu native tests so naming, locals, and variable validation can be
    asserted without real AWS calls. The terraform-aws-modules/eks v21 sub-modules
    cannot be silenced via override_module, so this gate is the practical
    workaround. Always true in real applies.
  EOT
}

variable "cluster_admin_arns" {
  type        = list(string)
  default     = []
  description = <<-EOT
    IAM principal ARNs (users/roles) that should hold permanent kubectl admin
    access via the cluster-admin EKS access entry. These principals also appear
    as KMS key administrators on the EKS encryption key (prevents key-policy
    drift on apply). Use `aws eks update-kubeconfig --role-arn <cluster_admin_role_arn>`
    after apply to obtain an admin kubeconfig.
  EOT
}

variable "console_admin_arns" {
  type        = list(string)
  default     = []
  description = <<-EOT
    IAM principal ARNs that need the AWS EKS *Console* UI (browser view of
    pods/services). Kept separate from cluster_admin_arns because the console
    needs both EKS access entries AND EC2 read-only for node details, while
    cluster admins need neither EC2 nor a long-lived console role.
  EOT
}

variable "ci_infra_role_arn" {
  type        = string
  default     = ""
  description = <<-EOT
    ARN of the GitHub Actions OIDC-assumable role that runs `tofu apply` in CI.
    Granted a stable EKS access entry + KMS admin so the kubernetes/helm
    providers can authenticate to the cluster during apply (instead of relying
    on cluster_creator_admin, which churns per-caller). Distinct from
    cluster_admin_arns (humans) to preserve a least-privilege boundary.
  EOT
}
