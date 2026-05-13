# modules/gitops

Installs ArgoCD via Helm and wires up an AppProject + Application for the greeter service.

## Usage

```hcl
module "gitops" {
  source      = "../../modules/gitops"
  environment = "local"   # or "dev" / "prod"
}
```

The `environment` variable selects `values-${environment}.yaml` from the greeter chart path in the repo.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `environment` | string | required | One of `local`, `dev`, `prod` |
| `greeter_repo_url` | string | `https://github.com/GRBurst/infra-challenge.git` | Git repo URL |
| `greeter_chart_path` | string | `charts/greeter` | Path to Helm chart in repo |
| `greeter_target_revision` | string | `HEAD` | Git revision to track |
| `argocd_chart_version` | string | `7.7.0` | ArgoCD Helm chart version |
| `argocd_namespace` | string | `argocd` | Namespace for ArgoCD |
| `greeter_namespace` | string | `greeter` | Namespace for greeter app |

## Outputs

| Name | Description |
|------|-------------|
| `argocd_namespace` | Namespace where ArgoCD is deployed |
| `greeter_namespace` | Namespace where greeter is deployed |
| `application_name` | ArgoCD Application name |
