# modules/gitops

Installs ArgoCD via Helm and wires up an AppProject + Application for the greeter service.

> This module is generated from `variables.tf` and `outputs.tf`; keep them in sync - `just test-all` enforces it.

## Usage

```hcl
module "gitops" {
  source      = "../../modules/gitops"
  environment = "local"   # or "dev" / "prod"
  repo_url    = "https://github.com/GRBurst/infra-challenge.git"
}
```

The `environment` variable selects `values-${environment}.yaml` from the greeter chart path in the repo.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `environment` | string | required | One of `local`, `dev`, `prod` |
| `repo_url` | string | required | Git repo URL ArgoCD pulls from |
| `target_revision` | string | `HEAD` | Git ref (branch/tag/commit) ArgoCD tracks |
| `greeter_chart_path` | string | `charts/greeter` | Path to Helm chart in repo |
| `argocd_chart_version` | string | `9.5.14` | ArgoCD Helm chart version |
| `argocd_namespace` | string | `argocd` | Namespace for ArgoCD |
| `greeter_namespace` | string | `greeter` | Namespace for greeter app |
| `create_apps` | bool | `true` | Create ArgoCD AppProject and Application manifests |

## Outputs

| Name | Description |
|------|-------------|
| `argocd_namespace` | Namespace where ArgoCD is deployed |
| `greeter_namespace` | Namespace where greeter is deployed |
| `application_name` | ArgoCD Application name |
| `application_repo_url` | Git repo URL the Application tracks |
| `application_target_revision` | Git revision the Application tracks |
