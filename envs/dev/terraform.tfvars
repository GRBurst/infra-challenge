# Replace with your own IAM ARN (user or role) before applying.
cluster_admin_arns = ["arn:aws:iam::532287339094:user/julius"]

# Git ref ArgoCD tracks. Must stay in sync with DEPLOY_BRANCH in ci.yml.
target_revision = "challenge"
