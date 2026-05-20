# infra-challenge

A production-minded GitOps skeleton on AWS: a Go greeter service running in EKS,
deployed via ArgoCD, built by GitHub Actions with Nix, with state in S3.

| Responsibility | Tool / Infrastructure |
| ------------------ | -------------------------------------- |
| Infrastructure | OpenTofu (Terraform) |
| Build | Nix (reproducible binary + image) |
| Container registry | AWS ECR |
| Compute | AWS EKS (managed node groups) |
| CI | GitHub Actions + OIDC (no stored keys) |
| CD / GitOps | ArgoCD (pull-based, 3-min polling) |
| App packaging | Helm chart |
| Local dev | k3d + Gitea + ArgoCD |

______________________________________________________________________

## Prerequisites

All tools are provided by the [Nix](https://nixos.org/) dev shell. With Nix
installed, run:

```sh
nix develop
```

This drops you into a shell with: `opentofu`, `just`, `kubectl`, `helm`, `k3d`,
`awscli2`, `trivy` (let's hope they have better supply chain measures in place
now :-) ), `tflint`, `jq`, `yq`, `k9s`, and all formatters/linters. No manual
installs required. These are many tools for a simple demo, but I mostly compied
those from existing projects I setup and am working on.

`just` is the task runner. Run `just` with no arguments to list all available
commands. This is heavily used to centralize all scripting parts.

> Note: This is a nix flake setup. It requires an initialized git repository to
> work and a flake support enabled, see
> [Flakes](https://nixos.wiki/wiki/flakes).

### Quick app test (no infrastructure)

The same `flake.nix` that provides the dev shell also builds the greeter binary
and the Docker image published by CI:

```sh
nix build                              # → ./result/bin/greeter
HELLO_TAG=test HOSTNAME=local nix run  # runs the service on :8080
nix build .#dockerImage                # → OCI tarball; load with: docker load -i result
nix flake check                        # verifies both artifacts build cleanly
```

______________________________________________________________________

## Repository layout

```
.github/workflows/ci.yml   CI pipeline (check, build, deploy)
charts/greeter/            Helm chart for the greeter service
  values.yaml              defaults
  values-dev.yaml          dev overrides - image.tag, helloTag, buildTime (CI-managed)
envs/
  dev/                     AWS dev environment (OpenTofu root)
  local/                   Local k3d environment (OpenTofu root)
modules/
  bootstrap/               Per-account: S3 state bucket, DynamoDB, OIDC, CI IAM roles
  platform/                Per-env: VPC, EKS, ECR, cluster-admin IAM role
  gitea/                   Gitea service for local git service setup
  gitops/                  ArgoCD Helm release + AppProject + Application CRs
greeter.go                 Go service source
flake.nix                  Nix build + devShell definition
justfile                   All task-runner commands
```

The modules make heavily use of terraform modules for most parts. This works
well for most setups, but can get more complicated or might be overkill in some
ways. It is always a balancing act between maintainability, best fit and
boilerplate. However, in most cases it can drastically reduce the burden when
setting up basic infrastructure and I would usually consider it as the way to
go.

______________________________________________________________________

## Local development (k3d)

The local environment runs a full GitOps loop - Gitea (self-hosted Git) + ArgoCD

- inside a k3d cluster. ArgoCD watches a local mirror of the current branch, so
  pushes to Gitea trigger resyncs without touching GitHub.

Although not required, I had some skeleton from a previous project already in
place which I extended for a playground. It is generally nice to to have a local
setup running, though this gets more and more complicated with complex
infrastructure. Still, it allows lots of testing and verification in a very
quick local loop.

### Start the local stack

```sh
just dev-up
```

This creates a k3d cluster, builds the greeter image with Nix, pushes it to the
in-cluster registry, deploys Gitea and ArgoCD via OpenTofu, bootstraps the Gitea
repo, and applies the ArgoCD Application CR. Takes a few minutes on first run.

Once ready:

| Service | URL | Credentials |
| ------- | -------------------------------------------------- | ---------------------------- |
| Greeter | <http://localhost:8081/> | --- |
| Gitea | <http://localhost:3000> | gitea-admin / gitea-admin |
| ArgoCD | run `just argocd-ui`, then <http://localhost:8080> | admin / (printed by command) |

### Iterate on a change

```sh
# Edit greeter.go or charts/greeter/...
just dev-image          # rebuild + push image to local registry
git add .               # or specify which files you want to commit
git commit -m "my msg"
just gitea-setup        # force-push current branch to Gitea
just gitea-sync         # trigger immediate ArgoCD re-evaluation (you can wait for it to trigger automatically as well)
just dev-check          # wait for rollout + assert Synced + Healthy
```

### Run smoke tests

```sh
just dev-test
```

### Tear down

```sh
just dev-down
```

______________________________________________________________________

## AWS dev environment

### First-time bootstrap

The bootstrap is a one-time manual step. After that, CI owns all applies.

**1. Authenticate to AWS**

```sh
aws login           # or: aws configure
eval "$(aws configure export-credentials --format env)"
```

Why this `eval` workaround? Simply put: `aws login` creates modern, temporary
credentials with OAuth cached. OpenTofu's backend engine for the state does not
understand this yet. I was surprised by this myself. When using `aws sso login`,
you might not run into this limitation.

**2. Provision infrastructure**

```sh
just dev-infra-up       # VPC + EKS + ECR + IAM (stage 1)
just dev-gitops-up      # ArgoCD + Application CRs (stage 2)
```

Stage 2 is split from stage 1 because the Kubernetes provider needs the EKS
cluster to exist before it can validate ArgoCD CRDs at plan time.

**3. Populate GitHub Environment variables**

The `dev` GitHub Environment needs four variables so CI can assume roles and
push images. Run once after `dev-infra-up`:

```sh
gh variable set ECR_REPOSITORY_URL --env dev --body "$(cd envs/dev && tofu output -raw ecr_repository_url)"
gh variable set ECR_REGISTRY_HOST  --env dev --body "$(cd envs/dev && tofu output -raw ecr_registry_host)"
gh variable set CI_APP_ROLE_ARN    --env dev --body "$(cd envs/dev && tofu output -raw ci_app_role_arn)"
gh variable set CI_INFRA_ROLE_ARN  --env dev --body "$(cd envs/dev && tofu output -raw ci_infra_role_arn)"
```

These are not secrets, but IAM role ARNs and ECR URLs. After this step, push to
the `challenge` branch and CI takes over.

### CI/CD pipeline

Every push to `challenge` runs four jobs:

| Job | Triggered by | What it does |
| ----------------- | ---------------------------- | ----------------------------------------------------------------------- |
| `check` | all branches | fmt, lint, tflint, security scan, OpenTofu + Helm + Go tests |
| `build-and-push` | `challenge` branch | Nix build → Trivy scan → push to ECR → commit updated `values-dev.yaml` |
| `deploy-platform` | `challenge` (after check) | `tofu apply` for bootstrap + platform modules |
| `deploy-gitops` | `challenge` (after platform) | two-phase apply: ArgoCD Helm release, then Application CRs |

Runs on ubuntu latest with nix.

Authentication is OIDC-based - no IAM keys are stored in GitHub Secrets.
`build-and-push` uses `ci_app_role` (ECR push only); the deploy jobs use
`ci_infra_role` (scoped to `environment: dev`).

After `build-and-push` updates `charts/greeter/values-dev.yaml`, ArgoCD detects
the commit within 3 minutes, renders the chart with the new image tag, and rolls
out the new pods. The `[skip ci]` marker on that commit prevents a loop
(workaround / simplification for this single repo setup).

### Accessing the cluster (kubectl)

After bootstrap, use the cluster-admin role output:

```sh
aws eks update-kubeconfig \
  --name hm-dev-eks \
  --region eu-central-1 \
  --role-arn "$(cd envs/dev && tofu output -raw cluster_admin_role_arn)"

kubectl get nodes
kubectl get pods -n greeter
```

This role is stable across CI re-applies because it is an explicit EKS access
entry, independent of who ran `tofu apply`.

### ArgoCD

ArgoCD runs inside the cluster with no public endpoint. Access it via
port-forward:

```sh
kubectl port-forward svc/argocd-server -n argocd 8080:80
# open http://localhost:8080
# username: admin
# password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

ArgoCD polls the `challenge` branch of this repository every 3 minutes. The
Application is configured with `automated.prune = true` and `selfHeal = true` -
any drift is corrected automatically.

### Greeter endpoints

The greeter is exposed on port 8080 via an AWS NLB. Get the endpoint:

```sh
kubectl get svc -n greeter greeter \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

| Endpoint | Description |
| ----------------------------- | ------------------------------------------------------------------------- |
| `GET /` | Returns `Hello, <client-ip>! I'm <pod-name>` |
| `GET /?textInjection=<text>` | Appends `<text>` (≤ 256 bytes) to the greeting |
| `GET /healthz` | Returns 200 (used by readiness + liveness probes) |
| `GET /version` | Returns `{"helloTag":"<sha>","buildTime":"<rfc3339>","hostname":"<pod>"}` |
| Response header `X-Hello-Tag` | Full git SHA on every response |

Quick verification:

```sh
NLB=$(kubectl get svc -n greeter greeter -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl "http://$NLB:8080/"
curl -s "http://$NLB:8080/version" | jq .
curl -sI "http://$NLB:8080/" | grep X-Hello-Tag
```

Or use the justfile shortcut after kubeconfig is configured:

```sh
just dev-infra-smoke
```

### Tear down

Destroys EKS, VPC, and ECR. The S3 state bucket and DynamoDB table are retained
(they are cheap and hold history).

```sh
just dev-infra-down
```

______________________________________________________________________

## Testing

```sh
just test-all           # Go + Helm + OpenTofu + shellcheck + CI workflow structure
just test-go            # Go unit tests
just test-chart         # Helm lint + helm-unittest
just test               # OpenTofu native tests for all modules and envs
just test-ci-workflow   # Static assertions on ci.yml structure (yq-based)
just dev-test           # Smoke tests against the local k3d cluster
just dev-infra-smoke    # Smoke tests against the AWS dev environment
```

______________________________________________________________________

## Development workflow

A typical change:

1. Edit `greeter.go`, `charts/greeter/`, or infrastructure modules.
2. `just check` - runs fmt + lint + validate + tflint locally.
3. `just test-all` - full test suite (no network required; uses mock providers).
4. Commit and push to `challenge`.
5. CI runs `check`, then `build-and-push` (new image + updated
   `values-dev.yaml`).
6. ArgoCD detects the values commit within 3 minutes and rolls out the new
   image.
7. Verify: `just dev-infra-smoke`.

### Adding a new environment

Each environment lives in its own `envs/<env>/` directory and AWS account. Copy
`envs/dev/`, update the account ID in `backend.tf` and `providers.tf`, run
`just dev-infra-up` and `just dev-gitops-up` from the new directory, then add a
matching GitHub Environment with the role ARNs from `tofu output`. Each account
needs its own OIDC provider - the `bootstrap` module provisions it. Gate prod
with required reviewers in GitHub Settings → Environments so no push deploys to
prod without approval.

### Making the repo private

ArgoCD currently reads the public repo without credentials. When the repo goes
private, create a Kubernetes Secret labeled
`argocd.argoproj.io/secret-type=repository` and apply it out-of-band - never via
OpenTofu, as credentials must not enter Tofu state. Use a GitHub App
(recommended: short-lived tokens, automatic rotation) or a read-only Deploy Key
as a simpler alternative.

______________________________________________________________________

## Tradeoffs and limitations

Conscious scope decisions made for this challenge. Each has a documented
production path.

| Limitation | Reason | Production path |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| HTTP-only on port 8080 (no TLS) | No ACM certificate provisioned | ACM + ALB Ingress Controller + port 443 |
| Single NAT Gateway | 3x cost for HA; acceptable for a challenge | `single_nat_gateway = false` in the VPC module |
| Trivy scan is non-blocking | Nix base image has unfixed upstream CVEs the app cannot patch | Pin `nixpkgs` revision, strip unused packages, re-enable `--exit-code 1` |
| ArgoCD UI not publicly exposed | Requires ALB + ACM + DNS. port-forward access sufficient for demo. Different story for self-hosted git services (e.g. gitlab, gitea). | ALB Ingress + ACM + Dex (GitHub SSO) |
| ArgoCD polls every 3 min (no webhooks) | Webhooks require a public ArgoCD endpoint | GitHub webhook → `argocd.server.service.type=LoadBalancer` |
| No Prometheus / Grafana | Full observability stack is out of scope | CloudWatch Container Insights or ADOT for K8s metrics |
| No image signing | Key management overhead not justified here | cosign + ECR + OPA/Gatekeeper admission policy |
| No network policies | Service mesh adds complexity with no app-level benefit yet | Calico or Cilium network policies per namespace |
| No IAM Roles for SA for the greeter | Greeter has no AWS API dependency | Add `aws_iam_role.greeter_irsa` in `modules/platform` when an AWS SDK call is needed |
| `ci_infra_role` has `AdministratorAccess` | Scoping requires enumerating all IaC actions | Replace with a least-privilege policy once the resource set stabilises |
| CI commit-back requires `git pull --rebase` before every push | After each build, CI commits updated `values-dev.yaml` back to the branch; any local checkout diverges by one commit | Replace with ArgoCD Image Updater, which writes directly to the cluster without touching the branch; or promote images via a separate `refs/heads/env/dev` values branch that developers never work on. Separate repositories for app and infra deployment would solve this by design. |

______________________________________________________________________

## Key commands reference

```sh
just                    # list all commands
just dev-up             # start local k3d stack
just dev-down           # tear down local k3d stack
just dev-infra-up       # provision AWS VPC + EKS + ECR (stage 1)
just dev-gitops-up      # deploy ArgoCD + Application CRs (stage 2)
just dev-infra-down     # destroy AWS EKS + VPC + ECR
just dev-infra-info     # print all OpenTofu outputs for dev env
just check              # full local CI check (fmt + lint + validate)
just fix                # auto-fix formatting and lint issues
just test-all           # run all tests
just fmt                # fix all formatting
```
