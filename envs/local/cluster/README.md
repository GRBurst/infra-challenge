# Local Development with k3d

Spin up a full offline GitOps stack (k3d + Gitea + ArgoCD + greeter) on your
machine in a few minutes.

## Prerequisites

- Docker daemon running
- Nix with flakes enabled (`nix develop` to enter the dev shell)
- Ports `3000` (Gitea), `5001` (registry), and `8081` (ingress) free on your
  host

## Bootstrap

```bash
nix develop       # enters dev shell with k3d, kubectl, helm, tofu, etc.
just dev-up       # creates cluster + Gitea + ArgoCD; tracks the current branch
```

`dev-up` is idempotent: if the cluster already exists it skips creation. It
auto-detects the current Git branch and configures ArgoCD to track it.

## Workflow (per-branch demos)

```bash
git checkout -b feature/demo-foo
just dev-up                       # ArgoCD now tracks feature/demo-foo

# edit + commit
vim greeter.go
git commit -am "demo: change message"

# push to in-cluster Gitea and force ArgoCD to refresh immediately
just seed-gitea-repo
just gitea-sync
just dev-test
```

ArgoCD reconciles within seconds; the pod rolls; `just dev-test` reflects the
change.

## Smoke test

```bash
just dev-test     # curl /healthz, /version, checks X-Hello-Tag header
```

## Tear down

```bash
just dev-down     # deletes the k3d cluster (Gitea PVC is lost with it)
```

## URLs

| What | URL | Credentials |
| ------------- | ------------------------------------------------------- | -------------------------- |
| Gitea Web UI | <http://localhost:3000> | gitea-admin / gitea-admin |
| Gitea push | <http://localhost:3000/gitea-admin/infra-challenge.git> | same |
| ArgoCD Web UI | port-forward (`just argocd-ui`) | admin / (initial password) |

## ArgoCD UI

```bash
just argocd-ui    # prints port-forward command + initial admin password
# open http://localhost:8080
```

## Repository layout

This directory holds the **imperative shell** for the local environment:

- `k3d-config.yaml` - k3d cluster spec (registry, port mappings, NodePort
  exposure for Gitea).
- `scripts/seed-gitea-repo.sh` - seeds the in-cluster Gitea repo and
  force-pushes the current branch.
- `scripts/smoke-test.sh` - HTTP smoke tests against the deployed greeter.

The **declarative layer** lives one directory up in `envs/local/` (OpenTofu
calling `modules/gitea` and `modules/gitops`).

## Troubleshooting

| Symptom | Fix |
| ------------------------------------- | ---------------------------------------------------------------------------------------- |
| `registry.localhost:5001` unreachable | Ensure `/etc/hosts` has `127.0.0.1 registry.localhost`, or use `127.0.0.1:5001` directly |
| Port 5001 already in use | Stop the conflicting service or edit `k3d-config.yaml` `hostPort` |
| Port 8081 already in use | Edit `k3d-config.yaml` port mapping |
| Port 3000 already in use | Edit `k3d-config.yaml` host port for the NodePort mapping |
| Cluster context missing | Run `k3d kubeconfig get infra-challenge >> ~/.kube/config` |
| Docker network issues | `docker network ls` - k3d creates `k3d-infra-challenge`; inspect if missing |
| `seed-gitea-repo` times out | `kubectl -n gitea get pods` - first image pull can be slow |
| ArgoCD shows `repo not found` | Re-run `just seed-gitea-repo`; check `kubectl -n gitea logs` |
| Push rejected, "non-fast-forward" | `seed-gitea-repo` force-pushes intentionally; this should not happen |
| Detached HEAD | `git checkout <branch>` before running `just dev-up` |
