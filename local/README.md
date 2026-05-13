# Local Development with k3d

Spin up a full GitOps stack (k3d + ArgoCD + greeter) on your machine in ~2 minutes.

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
|---------|-----|
| `registry.localhost:5001` unreachable | Ensure `/etc/hosts` has `127.0.0.1 registry.localhost`, or use `127.0.0.1:5001` directly |
| Port 5001 already in use | Stop the conflicting service or edit `local/k3d-config.yaml` `hostPort` |
| Port 8081 already in use | Edit `local/k3d-config.yaml` port mapping |
| Cluster context missing | Run `k3d kubeconfig get infra-challenge >> ~/.kube/config` |
| Docker network issues | `docker network ls` — k3d creates `k3d-infra-challenge`; inspect if missing |
