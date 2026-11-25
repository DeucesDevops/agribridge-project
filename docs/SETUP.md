# Setup

Build the project in this order. Each stage has a check you can run before
the next one. Commands assume the repository root, `us-east-1`, and kOps 1.36.2.

Install Terraform 1.14.6, kOps 1.36.2, kubectl 1.36.6, Helm 3.19, the AWS CLI
and Docker before you start. Nothing in this setup opens an SSH session.
`sshAccess` in `kops/cluster.yaml` is empty, and the launch templates have no
SSH key.

`scripts/apply-environment.sh` runs stages 2 and 3. The commands below are
the same steps, written out so each one can be run on its own.

## Stage 1. Run the app locally

```sh
cp .env.example .env
docker compose up --build -d --wait
```

Open http://localhost:8080 and sign in with a demo account from the root README.
`docker compose down` stops the stack and keeps the database volume.

## Stage 2. Create the Terraform state bucket

A rebuild starts with `scripts/bootstrap-state.sh`.

```
terraform/
├── bootstrap/                  # this stage, local state
├── modules/
│   ├── network/                # VPC, public subnets, routes, no NAT
│   ├── cluster/                # control plane, nodes, IAM, security groups
│   ├── dns/                    # zone and certificate
│   ├── storage/                # buckets, KMS, Secrets Manager
│   ├── identity/               # GitHub OIDC, CI role, IRSA
│   └── platform/               # Helm releases on the second apply
└── environments/
    ├── production/             # root the apply script runs
    └── dev/                    # separate state key
```

The production and dev roots store their state in this bucket, so they cannot
create it. `terraform/bootstrap` creates it and keeps its own local state. It
is not the kOps state bucket. Run later Terraform commands from the repository
root with `-chdir` pointed at `terraform/environments/production` or
`terraform/bootstrap`.

```sh
export GITHUB_TOKEN=...   # classic repo scope, or fine-grained Actions + Administration write
./scripts/bootstrap-state.sh
```

The script applies `terraform/bootstrap`. That creates `agribridge-tfstate-<account-id>`
with versioning, encryption and Block Public Access. It writes
`terraform/environments/production/backend.hcl` and
`terraform/environments/dev/backend.hcl` when a file is missing. Those files
are already in git for this account, so the script leaves them. The bucket is
`agribridge-tfstate-237258628535`.

`GITHUB_TOKEN` is a credential, in the same way the AWS credentials are.
Terraform uses it to publish Actions variables. It is not committed.

## Stage 3. Terraform and the kOps cluster

The cluster spec is `kops/cluster.yaml`: name `k8s.agribridge.deuces.dev`,
state store `s3://kops-state-607`, issuer bucket
`agribridge-oidc-237258628535`. One `t3.medium` control plane and two
`t3.large` workers. kOps 1.36.2 renders that spec with
`kops update cluster --target=terraform`. `scripts/patch_kops_terraform.py`
splits the VPC, subnets, and routes into `terraform/modules/network` and the
instances, IAM, and security groups into `terraform/modules/cluster`. The
subnets are public, so there is no NAT gateway. `terraform -chdir=terraform/environments/production apply` creates
that network, the instances, the security groups and the IAM, and uploads the
node configuration into the state bucket.

The render also writes the cluster certificates into the state bucket. Those
certificates and the Terraform have to come from the same run, so the apply
script refreshes the network and cluster modules before it applies. Commit the
refreshed files when the spec changes.

### Fresh account

```sh
export GITHUB_TOKEN=...
export AWS_REGION=us-east-1
export KOPS_STATE_STORE=s3://kops-state-607
./scripts/apply-environment.sh
```

The first run creates the public zone `agribridge.deuces.dev`, the kOps
buckets, and prints the zone's name servers. Give those four servers to the
registrar that hosts `deuces.dev`. Route 53 cannot change that parent. When
`dig NS agribridge.deuces.dev` returns the same servers, run the script again.

The second run does this:

```sh
./scripts/render-kops-terraform.sh
terraform -chdir=terraform/environments/production apply -var install_platform=false
kops export kubeconfig --admin --name k8s.agribridge.deuces.dev
kops validate cluster --name k8s.agribridge.deuces.dev --wait 15m
terraform -chdir=terraform/environments/production apply -var install_platform=true
```

`kops validate` can time out while `api.k8s.agribridge.deuces.dev` is still
propagating. A resolver that received `NXDOMAIN` during that window keeps the
negative answer until the cache expires, and the 15 minute wait then fails
even though the API is up. Wait for that cache to expire, or ask a resolver
that did not cache the failure, then run validate again and run the platform
apply. The script stops before that second apply when validate fails, so run
these two commands yourself:

```sh
kops validate cluster --name k8s.agribridge.deuces.dev --wait 15m
terraform -chdir=terraform/environments/production apply -var install_platform=true
```

The first apply creates the certificate, the secrets, the backup bucket, the
GitHub variables, and the cluster. The second apply installs External Secrets,
ExternalDNS, Argo CD, kube-prometheus-stack, Loki, and Promtail. It reads the
kubeconfig from `kops export kubeconfig --admin`. That admin credential is
stored in the kOps state bucket. The GitHub Actions role can read that bucket.
Treat the role as cluster-admin. The image-tag job does not assume it.

Merge this GitOps change to `main` before that second apply. Argo CD tracks
`main`. If `main` still runs `helm upgrade` while Argo CD is installed, the
two writers will fight. `selfHeal` puts the cluster back to git.

`install_platform` defaults to false. `terraform -chdir=terraform/environments/production apply` builds the
AWS resources and leaves the charts alone.

### Existing account

State already lives in `agribridge-tfstate-237258628535` under
`agribridge/terraform.tfstate`. The zone `agribridge.deuces.dev`, the bucket
`kops-state-607` and the bucket `agribridge-oidc-237258628535` already exist
and stay under Terraform. The script imports a bucket or the zone only when
it is in AWS and not yet in state. It does not remove them from state.

```sh
export GITHUB_TOKEN=...
export KOPS_STATE_STORE=s3://kops-state-607
./scripts/apply-environment.sh
```

The same imports by hand:

```sh
terraform -chdir=terraform/environments/production init -backend-config=backend.hcl

# Only if these are not already in the state. Skip an address Terraform cannot find.
terraform -chdir=terraform/environments/production import module.storage.aws_s3_bucket.kops_state kops-state-607
terraform -chdir=terraform/environments/production import module.storage.aws_s3_bucket.discovery agribridge-oidc-237258628535

# The apply script does not adopt an existing certificate or backup bucket.
# Import them only when they already exist in this account and are not in state.
CERT_ARN=$(aws acm list-certificates --region us-east-1 \
  --query "CertificateSummaryList[?DomainName=='agribridge.deuces.dev'].CertificateArn | [0]" \
  --output text)
if [ -n "$CERT_ARN" ] && [ "$CERT_ARN" != "None" ]; then
  terraform -chdir=terraform/environments/production import module.dns.aws_acm_certificate.app "$CERT_ARN"
fi
terraform -chdir=terraform/environments/production import module.storage.aws_s3_bucket.backups agribridge-backups-237258628535

# The zone used to be a data source. Adopt the real zone.
terraform -chdir=terraform/environments/production state rm data.aws_route53_zone.app
ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name agribridge.deuces.dev \
  --query "HostedZones[?Name=='agribridge.deuces.dev.'].Id | [0]" --output text)
terraform -chdir=terraform/environments/production import module.dns.aws_route53_zone.app "${ZONE_ID#/hostedzone/}"
```

If External Secrets and ExternalDNS were created with `attach_irsa=true`,
move them off the `[0]` address:

```sh
terraform -chdir=terraform/environments/production state mv 'aws_iam_role.external_secrets[0]' 'module.identity.aws_iam_role.irsa["external_secrets"]'
terraform -chdir=terraform/environments/production state mv 'aws_iam_role_policy.external_secrets[0]' 'module.identity.aws_iam_role_policy.irsa["external_secrets"]'
terraform -chdir=terraform/environments/production state mv 'aws_iam_role.external_dns[0]' 'module.identity.aws_iam_role.irsa["external_dns"]'
terraform -chdir=terraform/environments/production state mv 'aws_iam_role_policy.external_dns[0]' 'module.identity.aws_iam_role_policy.irsa["external_dns"]'
```

There is no cluster to import. The previous machines are gone. Terraform
creates them again from `terraform/modules/cluster`.

```sh
kops export kubeconfig --admin --name k8s.agribridge.deuces.dev
kubectl get nodes
```

## Stage 4. GitHub settings Terraform does not own

Terraform writes `AWS_ROLE_ARN`, `AWS_REGION`, `ACM_CERTIFICATE_ARN`,
`KOPS_STATE_STORE`, `KOPS_CLUSTER_NAME`, `ZONE_NAME`, `PRODUCTION_URL`,
`GRAFANA_URL`, `ARGOCD_URL`, `BACKUP_BUCKET` and `BACKUP_ROLE_PRODUCTION`. It also creates
the `production` environment and adds `github_reviewer` (default
`DeucesDevops`) as the required reviewer. `prevent_self_review` is false, so
that person can approve their own production deployment.

Create these yourself. They are credentials for systems outside this AWS account.

| Setting | Value |
|---|---|
| Secret `DOCKERHUB_USERNAME` | Docker Hub user. The previous repositories belong to `macroni607` |
| Secret `DOCKERHUB_TOKEN` | Docker Hub access token that can push those repositories |
| Secret `SONAR_TOKEN` | Optional. SonarQube is skipped when this is empty |
| Variable `SONAR_HOST_URL` | Optional. SonarQube is skipped when this is empty |

`API_IMAGE_REPOSITORY` and `WEB_IMAGE_REPOSITORY` default to
`docker.io/macroni607/agribridge-api` and `docker.io/macroni607/agribridge-web`.
Set them when the Docker Hub user is different. Make the repositories public
so the nodes can pull them.

You can delete an old `CLUSTER_NAME` variable. The workflow reads
`KOPS_CLUSTER_NAME`.

Push to `main`, or re-run the **CI/CD** workflow there. The run lints, tests,
scans, builds, and pushes both images to Docker Hub. It then waits on the
production environment. Approve that environment in GitHub. That approval is
the human gate. The job then commits the image tag to
`helm/agribridge/values-production.yaml` on `main`. Argo CD syncs the commit
into `agribridge-production`. Until that first commit, the tag in git is
`local` and the pods cannot pull an image.

The app is [https://production.agribridge.deuces.dev](https://production.agribridge.deuces.dev).
Grafana is [https://grafana.agribridge.deuces.dev](https://grafana.agribridge.deuces.dev).
Argo CD is [https://argocd.agribridge.deuces.dev](https://argocd.agribridge.deuces.dev).
The Argo CD username is `admin`. Read the generated password on your machine:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

Grafana's username and password are the `admin_user` and `admin_password` keys
in Secrets Manager `agribridge/grafana`. Read them on your machine and keep
the password out of git, issues, and chat:

```sh
aws secretsmanager get-secret-value --secret-id agribridge/grafana \
  --query SecretString --output text
```

The JSON has those two keys. `admin_user` is `admin`.

Prometheus is only inside the cluster. In Grafana, open Explore and pick the
Prometheus datasource. For the Prometheus UI itself:

```sh
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090
```

Production is the only deployed environment. `SEED_DEMO_DATA` is `false`, and
the API does not register users. After the first production deploy, load the
demo accounts once. The image has no `npm`, so call the seed module with
`node`. The pod already has `SEED_PASSWORD` from Secrets Manager
`agribridge/production`. The seed skips itself when any user row exists.

```sh
kubectl -n agribridge-production exec deploy/agribridge-api -- \
  node -e "import('./src/seed.js').then(m=>m.seedDemoData()).then(r=>{console.log(JSON.stringify(r,null,2));process.exit(0)}).catch(e=>{console.error(e);process.exit(1)})"
```

Sign in as `amina.yusuf@example.ng` (farmer),
`procurement@sahelmills.example` (buyer), or `agent@agribridge.example`
(agent). The password is the `SEED_PASSWORD` key in `agribridge/production`.
The seed also inserts more farmers, buyers, lots, and orders. Locally, Compose
does this on startup because `SEED_DEMO_DATA=true`, and the password is
`SEED_PASSWORD` in `.env`.

### Show a code change deploying

Work on `dev`, then merge `dev` into `main` to release. Argo CD tracks `main`
only. A push to `dev` does not change production.

1. Change something visible. A string on the dashboard is enough.
2. Open a pull request into `dev`, merge it, then merge `dev` into `main`.
3. Wait until **CI/CD** on that `main` commit has pushed the images. The job
   **Publish production image tags** stays yellow until you approve the
   `production` environment.
4. Approve it. The job commits `deploy: set production images to <sha> [skip ci]`
   as DeucesDevops. That commit does not start another build.
5. Open Argo CD. The application `agribridge` moves to Synced and Healthy.
   Git is read about every 60 seconds. To refresh immediately:

```sh
kubectl -n argocd annotate application agribridge argocd.argoproj.io/refresh=hard --overwrite
```

6. The public version endpoint returns the same SHA:

```sh
curl -fsS https://production.agribridge.deuces.dev/version
```

`gitSha` and `imageTag` match the commit that built the image. The running
pods use `docker.io/macroni607/agribridge-api` and
`docker.io/macroni607/agribridge-web` at that tag.

To roll back, set both `tag` lines in `values-production.yaml` back to the
previous image SHA and push that commit to `main` with `[skip ci]` in the
message. Argo CD syncs the older image. `selfHeal` puts the cluster back if
you only change it with `kubectl` or `helm rollback`. A revert of the tag
commit that does not contain `[skip ci]` starts a new build and, after the
next approval, writes a new tag.

## Stage 5. Show a backup and a restore

Production installs a CronJob that runs `pg_dump` at 02:15 UTC and uploads
the file to `s3://agribridge-backups-237258628535/production/`. A copy is also written to
`production/latest.sql`. Objects expire after 30 days.

```sh
./scripts/demo-backup-restore.sh agribridge-production
```

The script writes a marker row, takes a backup, changes the row, restores
`production/latest.sql`, and checks the marker is back to the dumped value.
It pauses Argo CD auto-sync, scales the API to 0 for the restore, scales it
back, and turns prune and selfHeal back on. Without that pause, selfHeal
would scale the API up in the middle of the restore.

To restore a named dump:

```sh
./scripts/restore-postgres.sh agribridge-production production/20261121T021500Z.sql
```

To take a backup without waiting for 02:15:

```sh
kubectl -n agribridge-production create job agribridge-backup-now \
  --from=cronjob/agribridge-postgres-backup
kubectl -n agribridge-production wait --for=condition=complete job/agribridge-backup-now --timeout=10m
```

## Stage 6. Roll back or tear down

Roll an image back by committing the previous tag, as the GitOps demo above
describes. That is the rollback that survives `selfHeal`.

Tear down with `scripts/teardown-environment.sh`. `terraform -chdir=terraform/environments/production destroy`
is the wrong first command. Argo CD owns the application. While that
Application exists, `selfHeal` recreates the Ingress. Delete the Application
first, while Argo CD is still running, so the finalizer removes the Ingress
and the load balancer can release the subnets. ExternalDNS is set to
`upsert-only`, so it does not delete the records it created, and the hosted
zone then refuses to delete. The kOps state bucket and the discovery bucket
have `prevent_destroy` set, so a destroy that still has them in state stops
there on purpose.

The script does this:

```sh
export GITHUB_TOKEN=...
export KOPS_STATE_STORE=s3://kops-state-607
kops export kubeconfig --admin --name k8s.agribridge.deuces.dev
kubectl delete application agribridge --namespace argocd --wait=true --timeout=180s
helm uninstall agribridge --namespace agribridge-production
terraform -chdir=terraform/environments/production destroy -var install_platform=true -target=module.platform
python3 scripts/route53_cleanup.py "$(terraform -chdir=terraform/environments/production output -raw zone_id)" --apply
terraform -chdir=terraform/environments/production state rm module.storage.aws_s3_bucket.kops_state
terraform -chdir=terraform/environments/production state rm module.storage.aws_s3_bucket_versioning.kops_state
terraform -chdir=terraform/environments/production state rm module.storage.aws_s3_bucket_server_side_encryption_configuration.kops_state
terraform -chdir=terraform/environments/production state rm module.storage.aws_s3_bucket_public_access_block.kops_state
terraform -chdir=terraform/environments/production state rm module.storage.aws_s3_bucket.discovery
terraform -chdir=terraform/environments/production state rm module.storage.aws_s3_bucket_public_access_block.discovery
terraform -chdir=terraform/environments/production state rm module.storage.aws_s3_bucket_policy.discovery
terraform -chdir=terraform/environments/production destroy -var install_platform=false
```

`state rm` keeps `kops-state-607` and `agribridge-oidc-237258628535` in the
account. The Terraform state bucket is also kept. Delete it yourself after
you no longer need the state:

```sh
aws s3 rb s3://agribridge-tfstate-237258628535 --force
```

`route53_cleanup.py` deletes A, AAAA and TXT records and leaves the zone apex
NS and SOA, plus the ACM validation CNAMEs, for Terraform.

If destroy stops because the platform module is still recorded and the API is
already gone:

```sh
terraform -chdir=terraform/environments/production state rm 'module.platform["production"]'
terraform -chdir=terraform/environments/production destroy -var install_platform=false
```
