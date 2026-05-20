- complete setup via OpenTofu / Terraform
- simple observability: monitoring + alerting
  - in real world: ELK + prometheus + ...
  - service mesh
- use kubernetes. in aws -> EKS
- self-healing
- single region for challenge (multi would make it more robust)
- greeter in docker via nix
- nix devops shell
- gitops: app repo commits into infra repo
  - HELLO_TAG to commit hash
- simple ci/cd
  - for prod, flux or argocd would be preferable
- no team boundaries -> usually you have an infra plane + an app plane and a
  contract between both repos

______________________________________________________________________

solution should be deployable into any AWS account
