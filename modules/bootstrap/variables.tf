variable "namespace" {
  type        = string
  description = "Usually an abbreviation of your organization name, e.g. 'acme'"
}

variable "environment" {
  type        = string
  description = "Environment, e.g., 'dev', 'staging', 'prod'"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository for OIDC in the format 'OrgName/RepoName'"
}
