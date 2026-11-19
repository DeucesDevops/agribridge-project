# Setup

Build the project in this order. Each stage has a check you can run before
the next one. Commands assume the repository root and `us-east-1`.

Install Terraform 1.14.6, kubectl 1.36.6, Helm 3.19, the AWS CLI and Docker
before you start. The machine that runs Terraform also needs `aws` on `PATH`
for the platform apply, because Terraform asks EKS for a token. Nothing in
this setup opens an SSH session.

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

This is the one AWS object Terraform does not create. Terraform stores its
state in the bucket, so the bucket has to exist before `terraform init`.

```sh
export GITHUB_TOKEN=...   # classic repo scope, or fine-grained Actions + Administration write
./scripts/bootstrap-state.sh
```

The script creates `agribridge-tfstate-<account-id>` with versioning,
encryption and Block Public Access, and writes `terraform/backend.hcl` when
that file is missing. The existing bucket for this account is
`agribridge-tfstate-237258628535`. Leave it. The script sees that it is
already there.

`GITHUB_TOKEN` is a credential, in the same way the AWS credentials are.
Terraform uses it to publish Actions variables. It is not committed.

## Stage 3. Terraform

### Fresh account

```sh
export GITHUB_TOKEN=...
export AWS_REGION=us-east-1
./scripts/apply-environment.sh
```

The first run creates the public zone `agribridge.deuces.dev` and prints its
name servers. Give those four servers to the registrar that hosts the parent
domain `deuces.dev`. Route 53 cannot change that parent. When `dig NS
agribridge.deuces.dev` returns the same servers, run the script again.

The second run applies the root twice:

```sh
terraform -chdir=terraform init -backend-config=backend.hcl
terraform -chdir=terraform apply -var install_platform=false
terraform -chdir=terraform apply -var install_platform=true
```

The first apply creates the zone, the certificate, the VPC, the EKS cluster,
the node group, the OIDC provider, the IAM roles, the Secrets Manager
secrets, the backup bucket and the GitHub variables. The second apply installs
the platform charts. The Helm provider has to speak to the API, and the API
does not exist until the first apply finishes, so the two applies stay
separate. Run the second one again any time. Once the charts are installed it
changes nothing.

`install_platform` defaults to false. A plain `terraform apply` builds the
AWS resources and leaves the charts alone.

### Existing account

State already lives in `agribridge-tfstate-237258628535` under
`agribridge/terraform.tfstate`. The zone `agribridge.deuces.dev` already
exists. The buckets `kops-state-607` and `agribridge-oidc-237258628535` are
still in the account and used to be in this state. The script does the
migration, then the two applies. Run it from a clean checkout:

```sh
export GITHUB_TOKEN=...
./scripts/apply-environment.sh
```

What the script changes in state, before the first apply:

```sh
terraform -chdir=terraform init -backend-config=backend.hcl

# Keep these buckets. They are no longer in the configuration, so leaving
# them in state would make the next apply delete them.
terraform -chdir=terraform state rm aws_s3_bucket.kops_state
terraform -chdir=terraform state rm aws_s3_bucket_versioning.kops_state
terraform -chdir=terraform state rm aws_s3_bucket_server_side_encryption_configuration.kops_state
terraform -chdir=terraform state rm aws_s3_bucket_public_access_block.kops_state
terraform -chdir=terraform state rm aws_s3_bucket.discovery
terraform -chdir=terraform state rm aws_s3_bucket_public_access_block.discovery
terraform -chdir=terraform state rm aws_s3_bucket_policy.discovery

# The zone used to be a data source. Import the real zone so Terraform
# adopts it instead of creating a second one.
terraform -chdir=terraform state rm data.aws_route53_zone.app
ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name agribridge.deuces.dev \
  --query "HostedZones[?Name=='agribridge.deuces.dev.'].Id | [0]" --output text)
terraform -chdir=terraform import aws_route53_zone.app "${ZONE_ID#/hostedzone/}"
```

If External Secrets and ExternalDNS were created with `attach_irsa=true`,
their addresses had a `[0]`. Move them:

```sh
terraform -chdir=terraform state mv 'aws_iam_role.external_secrets[0]' aws_iam_role.external_secrets
terraform -chdir=terraform state mv 'aws_iam_role_policy.external_secrets[0]' aws_iam_role_policy.external_secrets
terraform -chdir=terraform state mv 'aws_iam_role.external_dns[0]' aws_iam_role.external_dns
terraform -chdir=terraform state mv 'aws_iam_role_policy.external_dns[0]' aws_iam_role_policy.external_dns
```

Skip a `state mv` or `state rm` that says the address is not in state. A
fresh state only needs the zone import, and only when the zone already exists.

GitHub variables and environments that already exist are imported as
`agribridge-project:NAME` (the repository name, without the owner). The
script does that import when the GitHub API returns 200.

There is no EKS cluster to import. The previous cluster was kOps and it has
been deleted. Terraform creates the new one.

After the apply, kubeconfig is:

```sh
aws eks update-kubeconfig --name agribridge --region us-east-1
kubectl get nodes
```

The IAM user who ran apply is a cluster admin. The GitHub Actions role is
too, through an EKS access entry. The nodes have no SSH key.

## Stage 4. GitHub settings Terraform does not own

Terraform writes `AWS_ROLE_ARN`, `AWS_REGION`, `ACM_CERTIFICATE_ARN`,
`CLUSTER_NAME`, `ZONE_NAME`, `QA_URL`, `PRODUCTION_URL`, `GRAFANA_URL`,
`BACKUP_BUCKET`, `BACKUP_ROLE_PRODUCTION` and `BACKUP_ROLE_QA`. It also
creates the `qa` and `production` environments and adds `github_reviewer`
(default `DeucesDevops`) as the required reviewer on production.
`prevent_self_review` is false, so that person can approve their own
production deployment.

Create these yourself. They are credentials for systems outside this AWS
account.

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

You can delete old `KOPS_STATE_STORE` and `KOPS_CLUSTER_NAME` variables. The
workflow does not read them.

Push to `main`, or re-run the **CI/CD** workflow there. The run lints, tests,
scans, builds, pushes both images to Docker Hub, deploys QA, and then waits
on production. Approve the production environment in GitHub. That approval is
the human gate the pipeline is supposed to have.

QA is `https://qa.<zone>`. Production is `https://production.<zone>`.
Grafana is `https://grafana.<zone>`. The user is `admin`. The password is in
Secrets Manager:

```sh
aws secretsmanager get-secret-value --secret-id agribridge/grafana \
  --query SecretString --output text
```

The QA demo password is in `agribridge/qa`, field `SEED_PASSWORD`. Production
does not load demo users.

## Stage 5. Show a backup and a restore

Production installs a CronJob that runs `pg_dump` at 02:15 UTC and uploads
the file to `s3://<backup-bucket>/production/`. A copy is also written to
`production/latest.sql`. Objects expire after 30 days. QA has the same chart
switch and leaves it off. Set `backup.enabled: true` in `values-qa.yaml` and
redeploy when you want a QA copy under the `qa/` prefix.

```sh
./scripts/demo-backup-restore.sh agribridge-production
```

The script writes a marker row, takes a backup, changes the row, restores
`production/latest.sql`, and checks the marker is back to the dumped value.
It scales the API to 0 for the restore and scales it back afterwards.

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

Roll back an application release without rebuilding the cluster:

```sh
helm history agribridge --namespace agribridge-production
helm rollback agribridge REVISION --namespace agribridge-production
```

Use the same commands in `agribridge-qa`.

Tear down with `scripts/teardown-environment.sh`. A plain `terraform destroy`
is the wrong first command. The application Ingress is installed by GitHub
Actions, so Terraform will delete the load balancer controller while that
Ingress still exists and the Application Load Balancer will hold the subnets.
ExternalDNS is set to `upsert-only`, so it does not delete the records it
created, and the hosted zone then refuses to delete.

The script does this:

```sh
export GITHUB_TOKEN=...
aws eks update-kubeconfig --name agribridge --region us-east-1
helm uninstall agribridge --namespace agribridge-qa
helm uninstall agribridge --namespace agribridge-production
# Wait until no load balancer remains whose name starts with k8s-.
terraform -chdir=terraform destroy -var install_platform=true -target=module.platform
python3 scripts/route53_cleanup.py "$(terraform -chdir=terraform output -raw zone_id)" --apply
terraform -chdir=terraform destroy -var install_platform=false
```

`route53_cleanup.py` deletes A, AAAA and TXT records and leaves the zone apex
NS and SOA, plus the ACM validation CNAMEs, for Terraform.

The state bucket is kept. Delete it yourself after you no longer need the
state:

```sh
aws s3 rb s3://agribridge-tfstate-237258628535 --force
```

`kops-state-607` and `agribridge-oidc-237258628535` are also left behind.
Delete them the same way when you are finished with them. They are not part
of the EKS environment.

If destroy stops because the platform module is still in state and the API is
already gone:

```sh
terraform -chdir=terraform state rm 'module.platform'
terraform -chdir=terraform destroy -var install_platform=false
```
