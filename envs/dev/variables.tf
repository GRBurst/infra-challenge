variable "create_platform" {
  type        = bool
  default     = true
  description = "Whether to create platform resources (EKS, VPC, ECR). Set to false for offline testing."
}
