# Local Development with k3d

Spin up a full GitOps stack (k3d + ArgoCD + greeter) on your machine in ~2
minutes.

## Prerequisites

- Docker daemon running
- Nix with flakes enabled (`nix develop` to enter the dev shell)
- Ports `5001` (registry) and `8081` (ingress) free on your host

## Bootstrap

```bash
nix develop       # enters dev shell with k3d, kubectl, helm, tofu, etc.
just dev-up       # creates cluster, pushes image, applies OpenTofu (ArgoCD + Application)
```

`dev-up` is idempotent: if the cluster already exists it skips creation.

## Smoke test

```bash
just dev-test     # curl /healthz, /version, checks X-Hello-Tag header
```

## Tear down

```bash
just dev-down     # deletes the k3d cluster
```

## ArgoCD UI

After `just dev-up`:

```bash
kubectl --context k3d-infra-challenge port-forward svc/argocd-server -n argocd 8080:80
# open http://localhost:8080  (admin / initial password below)
kubectl --context k3d-infra-challenge -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

## Troubleshooting

| Symptom | Fix |
| ------------------------------------- | ---------------------------------------------------------------------------------------- |
| `registry.localhost:5001` unreachable | Ensure `/etc/hosts` has `127.0.0.1 registry.localhost`, or use `127.0.0.1:5001` directly |
| Port 5001 already in use | Stop the conflicting service or edit `local/k3d-config.yaml` `hostPort` |
| Port 8081 already in use | Edit `local/k3d-config.yaml` port mapping |
| Cluster context missing | Run `k3d kubeconfig get infra-challenge >> ~/.kube/config` |
| Docker network issues | `docker network ls` — k3d creates `k3d-infra-challenge`; inspect if missing |

## Local Gitea (optional, fully offline GitOps)

By default the local stack tracks the public GitHub repo. To take GitHub out of
the loop, deploy an in-cluster Gitea and have ArgoCD pull from it.

### Bring up with Gitea

```bash
just dev-up-gitea
```

This phases the bring-up:

- Creates the k3d cluster (or starts it).
- Builds and pushes the greeter image to the local registry.
- Deploys Gitea in the `gitea` namespace (SQLite, 1 Gi PVC, NodePort 30080,
  exposed on host port 3000).
- Creates `gitea-admin/infra-challenge` via the Gitea API and force-pushes the
  **current branch**.
- Deploys ArgoCD configured to track that branch on the in-cluster Gitea URL.

### Workflow (per-branch demos)

```bash
git checkout -b feature/demo-foo
just dev-up-gitea            # ArgoCD now tracks feature/demo-foo

# edit + commit
vim greeter.go
git commit -am "demo: change message"

# push to Gitea and force ArgoCD to refresh immediately
just gitea-setup
just gitea-sync
```

ArgoCD reconciles within seconds; pod rolls; `just dev-test` reflects the
change.

### URLs

| What | URL | Credentials |
| ------------- | ------------------------------------------------------- | -------------------------- |
| Gitea Web UI | <http://localhost:3000> | gitea-admin / gitea-admin |
| Gitea push | <http://localhost:3000/gitea-admin/infra-challenge.git> | same |
| ArgoCD Web UI | port-forward (`just argocd-ui`) | admin / (initial password) |

### Tear down

```bash
just dev-down   # destroys cluster; Gitea state lost (PVC cluster-scoped)
```

### Troubleshooting (Gitea)

| Symptom | Fix |
| --------------------------------- | ---------------------------------------------------------------- |
| Port 3000 already in use | Edit `local/k3d-config.yaml` host port |
| `gitea-setup` times out | `kubectl -n gitea get pods` — first image pull can be slow |
| ArgoCD shows `repo not found` | Re-run `just gitea-setup`; check `kubectl -n gitea logs` |
| Push rejected, "non-fast-forward" | `gitea-setup` force-pushes intentionally; this should not happen |
| Detached HEAD | `git checkout <branch>` before running `just dev-up-gitea` |
