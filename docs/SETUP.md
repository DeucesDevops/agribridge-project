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

This is the one AWS object Terraform does not create. Terraform stores its
own state there, so the bucket has to exist before `terraform init`. It is
not the kOps state bucket.

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

## Stage 3. Terraform and the kOps cluster

The cluster spec is `kops/cluster.yaml`: name `k8s.agribridge.deuces.dev`,
state store `s3://kops-state-607`, issuer bucket
`agribridge-oidc-237258628535`. One `t3.medium` control plane and two
`t3.large` workers. kOps 1.36.2 renders that spec to `terraform/kops` with
`kops update cluster --target=terraform`. `terraform apply` creates the VPC,
the instances, the security groups and the IAM, and uploads the node
configuration into the state bucket.

The render also writes the cluster certificates into the state bucket. Those
certificates and the Terraform have to come from the same run, so the apply
script refreshes `terraform/kops` before it applies. Commit the refreshed
files when the spec changes.

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
terraform -chdir=terraform apply -var install_platform=false
kops export kubeconfig --admin --name k8s.agribridge.deuces.dev
kops validate cluster --name k8s.agribridge.deuces.dev --wait 15m
terraform -chdir=terraform apply -var install_platform=true
```

The first apply creates the certificate, the secrets, the backup bucket, the
GitHub variables, and the cluster. The second apply installs External Secrets,
ExternalDNS and the monitoring charts. It reads the kubeconfig from
`kops export kubeconfig --admin`. That admin credential is stored in the kOps
state bucket. The GitHub Actions role can read that bucket, which is why the
deploy job can do the same export. Treat the role as cluster-admin.

`install_platform` defaults to false. A plain `terraform apply` builds the
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

The same imports by hand, after `terraform init`:

```sh
terraform -chdir=terraform init -backend-config=backend.hcl

# Only if these are not already in the state. Skip an address Terraform cannot find.
terraform -chdir=terraform import aws_s3_bucket.kops_state kops-state-607
terraform -chdir=terraform import aws_s3_bucket.discovery agribridge-oidc-237258628535

# The zone used to be a data source. Adopt the real zone.
terraform -chdir=terraform state rm data.aws_route53_zone.app
ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name agribridge.deuces.dev \
  --query "HostedZones[?Name=='agribridge.deuces.dev.'].Id | [0]" --output text)
terraform -chdir=terraform import aws_route53_zone.app "${ZONE_ID#/hostedzone/}"
```

If External Secrets and ExternalDNS were created with `attach_irsa=true`,
move them off the `[0]` address:

```sh
terraform -chdir=terraform state mv 'aws_iam_role.external_secrets[0]' aws_iam_role.external_secrets
terraform -chdir=terraform state mv 'aws_iam_role_policy.external_secrets[0]' aws_iam_role_policy.external_secrets
terraform -chdir=terraform state mv 'aws_iam_role.external_dns[0]' aws_iam_role.external_dns
terraform -chdir=terraform state mv 'aws_iam_role_policy.external_dns[0]' aws_iam_role_policy.external_dns
```

There is no cluster to import. The previous machines are gone. Terraform
creates them again from `terraform/kops`.

```sh
kops export kubeconfig --admin --name k8s.agribridge.deuces.dev
kubectl get nodes
```

## Stage 4. GitHub settings Terraform does not own

Terraform writes `AWS_ROLE_ARN`, `AWS_REGION`, `ACM_CERTIFICATE_ARN`,
`KOPS_STATE_STORE`, `KOPS_CLUSTER_NAME`, `ZONE_NAME`, `QA_URL`,
`PRODUCTION_URL`, `GRAFANA_URL`, `BACKUP_BUCKET`, `BACKUP_ROLE_PRODUCTION`
and `BACKUP_ROLE_QA`. It also creates the `qa` and `production` environments
and adds `github_reviewer` (default `DeucesDevops`) as the required reviewer
on production. `prevent_self_review` is false, so that person can approve
their own production deployment.

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
created, and the hosted zone then refuses to delete. The kOps state bucket
and the discovery bucket have `prevent_destroy` set, so a destroy that still
has them in state stops there on purpose.

The script does this:

```sh
export GITHUB_TOKEN=...
export KOPS_STATE_STORE=s3://kops-state-607
kops export kubeconfig --admin --name k8s.agribridge.deuces.dev
helm uninstall agribridge --namespace agribridge-qa
helm uninstall agribridge --namespace agribridge-production
terraform -chdir=terraform destroy -var install_platform=true -target=module.platform
python3 scripts/route53_cleanup.py "$(terraform -chdir=terraform output -raw zone_id)" --apply
terraform -chdir=terraform state rm aws_s3_bucket.kops_state
terraform -chdir=terraform state rm aws_s3_bucket_versioning.kops_state
terraform -chdir=terraform state rm aws_s3_bucket_server_side_encryption_configuration.kops_state
terraform -chdir=terraform state rm aws_s3_bucket_public_access_block.kops_state
terraform -chdir=terraform state rm aws_s3_bucket.discovery
terraform -chdir=terraform state rm aws_s3_bucket_public_access_block.discovery
terraform -chdir=terraform state rm aws_s3_bucket_policy.discovery
terraform -chdir=terraform destroy -var install_platform=false
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
terraform -chdir=terraform state rm 'module.platform'
terraform -chdir=terraform destroy -var install_platform=false
```
