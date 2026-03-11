# Hetzner Deployment (kube-hetzner, Prod Baseline)

Skyforge supports a third deployment path on Hetzner Cloud using
`terraform-hcloud-kube-hetzner`, alongside local `k3d` and Forward-hosted prod.
Current policy is explicit:
- local `k3d` is dev
- Hetzner is prod

## What This Path Includes

Phase 1 (enabled by default):
- pinned k3s version (`v1.35.2+k3s1`) via prod tfvars
- Cilium CNI
- dedicated control-plane API load balancer
- prod-sized nodepool baseline
- delete protection

Phase 2 (enabled/ready):
- `cert-manager` enabled
- etcd S3 backup inputs supported (set in prod baseline or extra tfvars)
- upgrade scheduling support via Terraform vars
- cluster autoscaler nodepool support
- KEDA worker autoscaling support in Skyforge Helm values

## Files

- Terraform root:
  - `deploy/hetzner/main.tf`
  - `deploy/hetzner/variables.tf`
- Terraform baseline:
  - `deploy/hetzner/profiles/prod.tfvars`
- Helm overlay baseline:
  - `deploy/examples/values-hetzner-prod.yaml`
- Scripts:
  - `scripts/deploy-skyforge-hetzner.sh`
  - `scripts/destroy-skyforge-hetzner.sh`
  - `scripts/hetzner-recreate-skyforge.sh`

## Credentials

Use local-only env files (for example `secrets/hetzner.env`) and never commit
tokens or SSH private keys.

Required variables:
- `TF_VAR_hcloud_token` (or `HCLOUD_TOKEN`)
- `TF_VAR_ssh_public_key` (or `SKYFORGE_HETZNER_SSH_PUBLIC_KEY`)
- `TF_VAR_ssh_private_key` (or `SKYFORGE_HETZNER_SSH_PRIVATE_KEY_FILE`)

Optional:
- `SKYFORGE_HETZNER_ENV_FILE` defaults to `secrets/hetzner.env`

Backups and external object storage are enforced by default. Set these in your
env file:

- `SKYFORGE_HETZNER_S3_ENDPOINT`
- `SKYFORGE_HETZNER_S3_BUCKET`
- `SKYFORGE_HETZNER_S3_ACCESS_KEY`
- `SKYFORGE_HETZNER_S3_SECRET_KEY`
- `SKYFORGE_HETZNER_S3_REGION` (optional, default `us-east-1`)
- `SKYFORGE_OBJECT_STORAGE_ENDPOINT` (Skyforge object storage endpoint)
- `SKYFORGE_OBJECT_STORAGE_ACCESS_KEY` (defaults to Hetzner S3 key if omitted)
- `SKYFORGE_OBJECT_STORAGE_SECRET_KEY` (defaults to Hetzner S3 secret if omitted)
- `SKYFORGE_HETZNER_AUTO_INSTALL_KEDA` (optional, default `true`)

## Deploy

```bash
cd /home/captainpacket/src/skyforge
./scripts/deploy-skyforge-hetzner.sh
```

Outputs:
- kubeconfig written to `.kubeconfig-skyforge-hetzner-prod`
- Terraform workspace `skyforge-prod`

## Destroy

```bash
./scripts/destroy-skyforge-hetzner.sh
```

## Recreate

```bash
./scripts/hetzner-recreate-skyforge.sh --force
```

## Model

The scripts are prod-only for Hetzner.

Terraform:
- baseline: `deploy/hetzner/profiles/prod.tfvars`
- optional: `--extra-tfvars <path>`

Helm:
- baseline: `deploy/examples/values-hetzner-prod.yaml`
- optional: `--extra-values <path>`

## Notes

- Module source is pinned in `deploy/hetzner/main.tf` for deterministic runs.
- Ingress controller is set to `none` at module level to avoid duplicate ingress
  stacks; Skyforge keeps its Gateway API path.
- Prod hard-enables etcd S3 backups at deploy time; deploy will
  fail fast when required S3 inputs are missing.
- Prod values disable in-cluster `s3gw`; deploy will fail fast when
  external object storage endpoint or credentials are missing.
- Prod includes an autoscaler burst pool (`ccx53`, min 0, max 8),
  allowing capacity bursts up to roughly 256 vCPU / 1 TiB when demanded.
- Config currently sets `allow_scheduling_on_control_plane=true` so lightweight
  workloads can use control-plane headroom at baseline.
