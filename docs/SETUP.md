# Setup

Build the project in this order. Each stage has a check you can run before
the next one. Commands assume the repository root and `us-east-1`.

Install Terraform 1.14.6, kOps 1.36.2, kubectl 1.36.6, Helm 3.19, the AWS CLI
and Docker before you start.

## Stage 1. Run the app locally

```sh
cp .env.example .env
docker compose up --build -d --wait
```

Open http://localhost:8080 and sign in with a demo account from the root README.
`docker compose down` stops the stack and keeps the database volume.

## Stage 2. Prepare AWS by hand

These objects have to exist before Terraform or kOps can run.

1. A public Route 53 hosted zone for `agribridge.deuces.dev` (or the zone you
   set as `zone_name`). At the registrar, delegate the subdomain to the four
   name servers Route 53 shows for that zone. Terraform looks the zone up. It
   does not create it.
2. An S3 bucket for Terraform state, for example `agribridge-tfstate-<account-id>`.
   Enable versioning, default encryption and Block Public Access. This bucket
   is not managed by Terraform, because Terraform needs it in order to start.

   ```sh
   aws s3api create-bucket --bucket agribridge-tfstate-ACCOUNT --region us-east-1
   aws s3api put-bucket-versioning --bucket agribridge-tfstate-ACCOUNT \
     --versioning-configuration Status=Enabled
   aws s3api put-public-access-block --bucket agribridge-tfstate-ACCOUNT \
     --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
   ```

3. Account-level S3 Block Public Access must allow a public bucket policy on
   the OIDC discovery bucket. kOps writes its service-account signing keys
   there, and AWS reads them without credentials. You can keep ACLs blocked.
   If the account setting blocks all public policies, the discovery bucket
   policy in stage 3 will be rejected.

Copy `terraform/backend.hcl.example` to `terraform/backend.hcl` and set the
state bucket name. The key stays `agribridge/terraform.tfstate`.

If this account already has `kops-state-607` or
`agribridge-oidc-237258628535`, import them after `terraform init` instead of
letting Terraform try to create them again:

```sh
terraform -chdir=terraform import aws_s3_bucket.kops_state kops-state-607
terraform -chdir=terraform import aws_s3_bucket.discovery agribridge-oidc-237258628535
```

A new account should change `kops_state_bucket`, `discovery_bucket`, and the
matching fields in `kops/cluster.yaml` (`configBase` and `discoveryStore`)
before the first apply. Bucket names in the manifest and in Terraform must be
the same, and the discovery bucket name cannot contain dots.

## Stage 3. Terraform, first apply

```sh
terraform -chdir=terraform init -backend-config=backend.hcl
terraform -chdir=terraform apply
```

This creates the kOps state bucket, the discovery bucket, the QA and production
secrets, the ACM certificate and the GitHub Actions role. Container images are
pushed to Docker Hub, not to a registry in this account.
It does not create the External Secrets or ExternalDNS roles yet.

Check the certificate:

```sh
terraform -chdir=terraform output certificate_arn
```

The value is empty until DNS validation finishes. Wait, then run
`terraform apply` again if the output is still unknown. `dig` should show the
validation records in the hosted zone.

## Stage 4. Create or update the kOps cluster

```sh
export AWS_REGION=us-east-1
export KOPS_STATE_STORE="$(terraform -chdir=terraform output -raw kops_state_store)"
export CLUSTER_NAME="$(terraform -chdir=terraform output -raw cluster_name)"
```

New cluster:

```sh
kops create -f kops/cluster.yaml
kops update cluster --name "$CLUSTER_NAME" --yes --admin
```

Cluster that is already in the state store:

```sh
kops replace -f kops/cluster.yaml
kops update cluster --name "$CLUSTER_NAME" --yes
```

`kops update cluster` without `--yes` prints the change and does not apply it.
Read that diff. The worker instance groups are `t3.large` so the monitoring
stack can schedule. The API load balancer allows `0.0.0.0/0` so GitHub-hosted
runners can deploy. Authentication is still required. Replace that CIDR in
`kops/cluster.yaml` if you only want a fixed admin network, and deploy from
that network instead.

```sh
kops validate cluster --name "$CLUSTER_NAME" --wait 15m
kops export kubeconfig --admin --name "$CLUSTER_NAME"
kubectl get nodes
```

kOps creates the OIDC provider, the AWS Load Balancer Controller and the EBS
CSI driver during this step. If a rebuilt control plane has empty etcd disks
but the state store still has etcd backups, follow the
[kOps etcd restore guide](https://kops.sigs.k8s.io/operations/etcd_backup_restore_encryption/)
before expecting the API to come up.

## Stage 5. IAM roles for External Secrets and ExternalDNS

```sh
terraform -chdir=terraform apply -var attach_irsa=true
terraform -chdir=terraform output external_secrets_role_arn
terraform -chdir=terraform output external_dns_role_arn
```

If apply cannot find the OIDC provider, list the providers and pass the URL
kOps registered:

```sh
aws iam list-open-id-connect-providers
terraform -chdir=terraform apply -var attach_irsa=true \
  -var oidc_issuer_url=https://THE_ISSUER_HOST
```

The default issuer is `https://<discovery-bucket>.s3.<region>.amazonaws.com`.
The trust policy audience is `amazonaws.com`, which is what the kOps
pod-identity webhook puts on the token.

## Stage 6. Install platform add-ons

Follow [platform/README.md](../platform/README.md). It installs External
Secrets, ExternalDNS, Loki, Tempo, Prometheus, Grafana and Promtail.

Check the load balancer controller and the secret store:

```sh
kubectl -n kube-system get deploy -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl -n external-secrets get pods
```

The QA demo password is in Secrets Manager. It is not in Git.

```sh
aws secretsmanager get-secret-value --secret-id agribridge/qa \
  --query SecretString --output text
```

Use that `SEED_PASSWORD` with the demo emails after QA is deployed.
Production does not load demo users.

## Stage 7. Point GitHub at Docker Hub and AWS

Create the secrets, variables and the `qa` and `production` environments listed
in [PIPELINE.md](PIPELINE.md). Add a required reviewer on `production` before
the first deploy.

| Setting | Value |
|---|---|
| Secret `DOCKERHUB_USERNAME` | Docker Hub user. The previous repositories belong to `macroni607` |
| Secret `DOCKERHUB_TOKEN` | Docker Hub access token that can push those repositories |
| Variable `AWS_ROLE_ARN` | Terraform output `github_actions_role_arn` |
| Variable `ACM_CERTIFICATE_ARN` | Terraform output `certificate_arn` |
| Variable `KOPS_STATE_STORE` | Terraform output `kops_state_store` |
| Variable `KOPS_CLUSTER_NAME` | Terraform output `cluster_name` |

`API_IMAGE_REPOSITORY` and `WEB_IMAGE_REPOSITORY` default to
`docker.io/macroni607/agribridge-api` and `docker.io/macroni607/agribridge-web`.
Set them when the Docker Hub user is different. Make the repositories public
so the nodes can pull them.

Push to `main`, or re-run the **CI/CD** workflow there. The run lints, tests,
scans, builds, pushes both images to Docker Hub, deploys QA, and then waits
on production.

QA is `https://qa.<zone>`. Production is `https://production.<zone>`.
ExternalDNS creates those records from the Ingress. The first certificate
and load balancer can take a few minutes.

## Stage 8. Roll back or tear down

Roll back an application release without rebuilding the cluster:

```sh
helm history agribridge --namespace agribridge-production
helm rollback agribridge REVISION --namespace agribridge-production
```

Use the same commands in `agribridge-qa`.

Tear down in this order:

```sh
helm uninstall agribridge --namespace agribridge-qa
helm uninstall agribridge --namespace agribridge-production
kops delete cluster --name "$CLUSTER_NAME" --yes
```

`terraform destroy` removes the secrets, certificate and IAM roles.
It will not delete the kOps state bucket or the discovery bucket, and it will
not delete the cluster if you skipped `kops delete`. Remove those two buckets
in the console after the cluster is gone. Delete leftover `qa` and
`production` DNS records if ExternalDNS leaves them behind.
