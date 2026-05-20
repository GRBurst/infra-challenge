# Instance-specific values. Backend block in backend.tf cannot interpolate
# these — keep namespace/environment/region there in sync with this file.
namespace   = "hm"
environment = "dev"
region      = "eu-central-1"
github_repo = "GRBurst/infra-challenge"

# Replace with your own IAM ARN (user or role) before applying.
cluster_admin_arns = ["arn:aws:iam::532287339094:user/julius"]

# Git ref ArgoCD tracks. Must stay in sync with DEPLOY_BRANCH in ci.yml.
target_revision = "challenge"
