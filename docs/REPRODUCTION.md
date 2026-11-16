# Reproduce AgriBridge

Use the course's simple sequence: run locally, prepare infrastructure, install the
platform, run CI/CD, verify staging, promote production, then operate it.
Terraform and maintenance run in your terminal. GitHub Actions runs application
CI/CD. Argo CD deploys the Helm chart.

## 1. Run locally

```sh
cp .env.example .env
docker compose up --build -d --wait
```

Open http://localhost:8080. `docker compose down` stops the stack and retains data.
For verification, install Node.js 22, Python and the dependencies in
`scripts/requirements.txt`, then run `make check` and `make local-verify`.

## 2. Prepare the existing kOps management instance

Connect to the EC2 instance named `kops` as `ubuntu`. Use standard Ubuntu; no
Ubuntu Pro subscription is required. Install Terraform 1.14.6, kOps 1.36.2,
kubectl compatible with Kubernetes 1.36.6, Helm 3.19.0, AWS CLI v2, Python, Git
and `dig` from their official sources. Use your authorized AWS profile or instance
identity; keep credentials outside Git and never print them.

Clone this repository, switch to the existing `dev` branch for source changes,
and run commands below from the repository root:

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r scripts/requirements.txt
umask 077
mkdir -p .runtime/automation
export AWS_REGION=us-east-1
export TF_VAR_expected_account_id=237258628535
export TF_VAR_discovery_bucket=agribridge-oidc-237258628535
export CLUSTER_NAME=k8s.agribridge.deuces.dev
export KOPS_STATE_STORE=s3://kops-state-607
export KUBECONFIG="$PWD/.runtime/kubeconfig"
aws sts get-caller-identity
```

Verify account `237258628535` before proceeding. Keep `DEPLOY_ENABLED=false`
and wait for any active delivery run to finish during infrastructure maintenance.
The `kops` instance is an administration host, not a Kubernetes worker.

## 3. Recover bootstrap state and verify DNS

This is an existing deployment: **use the existing remote state**, including when
resources have been removed. Do not run a fresh local bootstrap over retained
buckets or DNS. The state bucket and `bootstrap/terraform.tfstate` key must exist.
If either cannot be read, resolve access/recovery before proceeding.

If an older run left `terraform/bootstrap/backend_override.tf`, move it outside
the Terraform root: bootstrap now declares its S3 backend directly.

```sh
# Only when the obsolete generated file exists:
# mv terraform/bootstrap/backend_override.tf .runtime/bootstrap-backend-override.tf
terraform -chdir=terraform/bootstrap init -reconfigure -lockfile=readonly \
  -backend-config=../backend.hcl.example \
  -backend-config=key=bootstrap/terraform.tfstate
terraform -chdir=terraform/bootstrap plan -out=../../.runtime/bootstrap.tfplan
```

Review the plan. Apply it only if changes are intended, then export current outputs:

```sh
terraform -chdir=terraform/bootstrap apply ../../.runtime/bootstrap.tfplan
terraform -chdir=terraform/bootstrap output -json > .runtime/bootstrap-outputs.json
dig +short NS agribridge.deuces.dev
```

At Namecheap, keep `deuces.dev` on its existing DNS service. Its four **NS**
records with host `agribridge` must match the Route 53 zone's nameservers:

| Host | Type | Value |
|---|---|---|
| `agribridge` | NS | `ns-1354.awsdns-41.org` |
| `agribridge` | NS | `ns-2037.awsdns-62.co.uk` |
| `agribridge` | NS | `ns-292.awsdns-36.com` |
| `agribridge` | NS | `ns-944.awsdns-54.net` |

These records were verified against both providers on 16 November 2026 and
already matched. Keep unrelated records, including `taskflow` and mail settings.
Do not point the app at the management instance's public IP. Terraform manages
ACM validation and staging/production routing **inside Route 53** after the
load balancer exists. See [DNS.md](DNS.md).

For a genuinely new AWS account, bootstrap needs an initial local-state creation
and migration after its bucket exists. That is a separate account setup, not the
recovery procedure for this project.

## 4. Create or reconcile Kubernetes

Set `AGRIBRIDGE_API_CIDRS` to the management host's current public egress IP with
`/32`, or your narrow public VPN CIDR. Add your workstation's CIDR if it will
connect directly. Obtain these values from your authorized network/EC2 settings;
never use `0.0.0.0/0` or the checked-in documentation placeholder.

```sh
# Example syntax; replace with your real administrator addresses:
# export AGRIBRIDGE_API_CIDRS='PUBLIC_IP/32,VPN_PUBLIC_IP/32'
python scripts/prepare-cluster.py generate --outputs .runtime/bootstrap-outputs.json
terraform fmt -recursive terraform/generated/kops
terraform -chdir=terraform/cluster init -reconfigure -lockfile=readonly \
  -backend-config=../backend.hcl.example \
  -backend-config=key=kops/terraform.tfstate
terraform -chdir=terraform/cluster validate
terraform -chdir=terraform/cluster plan -out=../../.runtime/cluster.tfplan
```

Review instance counts, standard Ubuntu images, networking and resource actions.
Then apply the exact saved plan and verify the cluster:

```sh
terraform -chdir=terraform/cluster apply ../../.runtime/cluster.tfplan
kops export kubeconfig "$CLUSTER_NAME" --admin=1h --kubeconfig "$KUBECONFIG"
chmod 600 "$KUBECONFIG"
kubectl config current-context
kops validate cluster "$CLUSTER_NAME" --wait=15m
python scripts/prepare-cluster.py wait
```

The context must be `k8s.agribridge.deuces.dev`. The helper generates kOps
Terraform and preserves its bootstrap compatibility fix; Terraform provisions
the resources. Do not also run `kops update --yes`, which bypasses Terraform.

### Recovery when reusing an old kOps state store

If the replacement control plane has empty etcd disks, but the S3 store retains
`etcd-cluster-created`, etcd-manager can report **0 members registered; must issue
restore-backup command**. The API will not start and its DNS record can remain
absent. Repeated Terraform applies do not repair that condition.

Use the official `etcd-manager-ctl` client with authorized access to the retained
backup store. The client is also included in the running etcd-manager container
image. List both stores and choose verified backups from before the teardown:

```sh
etcd-manager-ctl --backup-store=s3://kops-state-607/k8s.agribridge.deuces.dev/backups/etcd/main list-backups
etcd-manager-ctl --backup-store=s3://kops-state-607/k8s.agribridge.deuces.dev/backups/etcd/events list-backups
```

Queue a restore for each store using its exact listed backup name:

```sh
# Replace MAIN_BACKUP and EVENTS_BACKUP with the selected names.
etcd-manager-ctl --backup-store=s3://kops-state-607/k8s.agribridge.deuces.dev/backups/etcd/main restore-backup "$MAIN_BACKUP"
etcd-manager-ctl --backup-store=s3://kops-state-607/k8s.agribridge.deuces.dev/backups/etcd/events restore-backup "$EVENTS_BACKUP"
```

Inspect the queued commands and recovery logs. Follow the
[official kOps recovery procedure](https://kops.sigs.k8s.io/operations/etcd_backup_restore_encryption/)
for restarting etcd-manager when required, then repeat cluster validation and
controller readiness checks. Preserve the backup objects and Terraform state;
do not clear the S3 control markers to force an empty cluster.

Etcd recovery restores Kubernetes metadata. PostgreSQL data needs its retained
EBS volume or a separately verified database backup. Check storage identities
before changing claims or declaring application data recovered.

## 5. Configure AWS application services

```sh
cp terraform/terraform.tfvars.example .runtime/services.tfvars
terraform -chdir=terraform init -reconfigure -lockfile=readonly \
  -backend-config=backend.hcl.example \
  -backend-config=key=services/terraform.tfstate
terraform -chdir=terraform plan -var-file=../.runtime/services.tfvars \
  -out=../.runtime/services.tfplan
```

Review the plan, especially secret recreation, IAM, certificates and retained
backups. Apply it, then refresh **non-secret references** in GitOps values:

```sh
terraform -chdir=terraform apply ../.runtime/services.tfplan
for environment in staging production; do
  aws ssm get-parameter --region us-east-1 \
    --name "/agribridge/$environment/deployment" \
    --query Parameter.Value --output text > ".runtime/$environment.json"
  python scripts/release.py configure "$environment" ".runtime/$environment.json"
done
```

Review `argocd/*-values.yaml`. Commit configuration changes on `dev`, push `dev`,
open a PR to `main`, inspect its checks, and merge through GitHub. Fast-forward
`dev` to the resulting merge commit. Keep deployment disabled until the platform
is ready. Runtime passwords stay in Secrets Manager and private Terraform state.

## 6. Install the platform

Create the platform input from the services output; do not copy secret values:

```sh
terraform -chdir=terraform output -json platform > .runtime/platform.json
python - <<'PYTHON'
import json, os
from pathlib import Path
Path('.runtime/platform.tfvars.json').write_text(json.dumps({
    'platform': json.loads(Path('.runtime/platform.json').read_text()),
    'kubeconfig_path': os.environ['KUBECONFIG'],
    'expected_account_id': '237258628535',
    'enable_argocd': True,
    'enable_legacy_pipeline': False,
}))
PYTHON
terraform -chdir=terraform/platform init -reconfigure -lockfile=readonly \
  -backend-config=../backend.hcl.example \
  -backend-config=key=platform/terraform.tfstate
terraform -chdir=terraform/platform plan \
  -var-file=../../.runtime/platform.tfvars.json -out=../../.runtime/platform.tfplan
```

Review, then apply the saved plan:

```sh
terraform -chdir=terraform/platform apply ../../.runtime/platform.tfplan
kubectl -n argocd get applications
kubectl -n ingress get services
terraform -chdir=terraform/platform output app_urls
```

Terraform installs External Secrets, ingress, Prometheus/Grafana, Fluent Bit and
Argo CD. Argo CD deploys application resources. Use only Argo CD for the app;
do not run a competing `helm upgrade` against it. A timed-out install needs
inspection and a fresh plan, not deletion of Terraform state.

## 7. Deliver the application

Configure Docker Hub and optional SonarQube settings from
[CONFIGURATION.md](CONFIGURATION.md). Set `DEPLOY_ENABLED=true` once the platform
is ready and GitOps references on `main` match it. Run `delivery.yaml` from `main`
or merge a checked source change from `dev`.

CI runs security scans, lint, coverage, PostgreSQL integration tests, optional
SonarQube, Docker build/runtime tests, image scans and SBOMs. It publishes the
same tested images, records immutable digests in staging, waits for Argo CD and
verifies HTTPS/build identity. Only then does it promote those digests to
production. No infrastructure workflow or self-hosted runner is required.

## 8. Verify and operate

Follow [OPERATIONS.md](OPERATIONS.md) for direct health checks, backups, isolated
restore tests, monitoring, rollback and reverse-order teardown. Record actual
workflow URLs and live results separately from offline tests. A passing source
check does not establish that AWS or SonarQube is running.
