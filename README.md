## Local AWS auth

- Run `aws login`, then
- `eval "$(aws configure export-credentials --format env)"`

## CI deploy flow

`.github/workflows/ci.yml` runs the following jobs on every push to `main`:

| Job | Purpose |
| ----------------- | ------------------------------------------------------------- |
| `check` | fmt, lint, tflint, security scan, OpenTofu + Helm + Go tests |
| `build-and-push` | Nix-builds the greeter image, scans with trivy, pushes to ECR |
| `deploy-platform` | `tofu apply -target=module.bootstrap -target=module.platform` |
| `deploy-gitops` | full `tofu apply` (deploys ArgoCD + greeter Application CR) |

Both deploy jobs assume `ci_infra_role` via GitHub OIDC. The two-phase apply
exists because `envs/dev/providers.tf` configures `helm`/`kubernetes` providers
from `data.aws_eks_cluster.this` — that data source must succeed before phase 2
can plan.

### One-time GitHub Environment bootstrap

Before CI can deploy, the `dev` GitHub Environment must have four variables
populated from the OpenTofu outputs of `envs/dev`:

| GitHub variable | OpenTofu output | Consumer |
| -------------------- | -------------------- | ---------------------------------- |
| `CI_INFRA_ROLE_ARN` | `ci_infra_role_arn` | `deploy-platform`, `deploy-gitops` |
| `CI_APP_ROLE_ARN` | `ci_app_role_arn` | `build-and-push` |
| `ECR_REPOSITORY_URL` | `ecr_repository_url` | `build-and-push` |
| `ECR_REGISTRY_HOST` | `ecr_registry_host` | `build-and-push` |

This can be achieved by using the gh tool:

```sh
gh variable set ECR_REPOSITORY_URL --env dev --body "$(cd envs/dev && tofu output -raw ecr_repository_url)"
gh variable set ECR_REGISTRY_HOST  --env dev --body "$(cd envs/dev && tofu output -raw ecr_registry_host)"
gh variable set CI_APP_ROLE_ARN    --env dev --body "$(cd envs/dev && tofu output -raw ci_app_role_arn)"
gh variable set CI_INFRA_ROLE_ARN  --env dev --body "$(cd envs/dev && tofu output -raw ci_infra_role_arn)"
```

Bootstrap procedure:

- Apply infra locally once: `just dev-infra-up`.
- Read outputs: `just dev-infra-info`.
- In GitHub → Settings → Environments → `dev` → Variables, add each value above.
  None are credentials.
- Push to `main` — `deploy-platform` and `deploy-gitops` then take over.

The `[skip ci]` marker on the values-dev.yaml commit-back prevents loops.
