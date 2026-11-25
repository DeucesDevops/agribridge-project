# Production

Root module for the only application environment. It calls the modules under
`terraform/modules` and passes outputs between them. Provider and backend
blocks live here, not in the modules.

| Module | What it creates |
|---|---|
| `dns` | Public Route 53 zone, ACM certificate, validation records |
| `storage` | kOps state bucket, OIDC discovery bucket, backup bucket, KMS, Secrets Manager |
| `cluster` | kOps-rendered VPC, instances, security groups, node IAM, issuer |
| `identity` | GitHub OIDC provider, Actions role, IRSA, Actions variables |
| `platform` | Helm releases, only when `install_platform` is true |
| `network` | VPC, public subnets, internet gateway, route table. No NAT |

kOps also installs the AWS Load Balancer Controller, the EBS CSI driver and
the pod-identity webhook. The launch templates have no SSH key. `sshAccess`
in the cluster spec is empty. The API security group allows 443 from the
internet so GitHub-hosted runners can deploy. Authentication is still required.

Grafana is https://grafana.agribridge.deuces.dev on the same load balancer.
The Grafana Service is a NodePort and the Ingress uses instance targets, in
the load balancer group `agribridge`, because Calico pod IPs are not routable
from the VPC. Anonymous access and sign-up are off. The username and password
are the `admin_user` and `admin_password` keys in Secrets Manager
`agribridge/grafana`. Prometheus has no Ingress. The app is
https://production.agribridge.deuces.dev. Argo CD is
https://argocd.agribridge.deuces.dev, with the same NodePort and instance-target
pattern. The username is `admin`. Read the generated password with
`terraform output -raw argocd_admin_password_command` and run that command.
The password is not in git.

Removing a Helm release from `modules/platform` uninstalls it on the next
`terraform apply -var install_platform=true`. Leave the address in state so
Terraform can destroy it. `install_platform` has to stay true on that apply.
The default is false, and a false value drops the whole platform module for
that run. The module address is `module.platform["production"]`.

The GitHub role can run `kops export kubeconfig --admin`. The admin credential
is in the kOps state bucket. That is cluster-admin access. The image-tag job
does not assume the role. It pushes a commit, and Argo CD applies it.

## What stays outside this root

The Terraform state bucket is created by `terraform/bootstrap` via
`scripts/bootstrap-state.sh`. Terraform stores its state there, so this root
cannot create that bucket itself. The bucket is versioned, encrypted and
private. State holds the generated passwords. That is why the bucket is not
in git. It is not `kops-state-607`.

The parent domain `deuces.dev` is delegated at the registrar. Terraform prints
`name_servers`. Someone has to publish those at the registrar.

`GITHUB_TOKEN`, the Docker Hub token and the optional SonarQube token are
credentials for accounts this root does not own.

## Apply

```sh
export GITHUB_TOKEN=...
export KOPS_STATE_STORE=s3://kops-state-607
./scripts/apply-environment.sh
```

That creates the zone and the kOps buckets, asks you to delegate DNS, then:

```sh
./scripts/render-kops-terraform.sh
terraform -chdir=terraform/environments/production apply -var install_platform=false
kops export kubeconfig --admin --name k8s.agribridge.deuces.dev
kops validate cluster --name k8s.agribridge.deuces.dev --wait 15m
terraform -chdir=terraform/environments/production apply -var install_platform=true
```

If validate times out because a resolver cached `NXDOMAIN` for
`api.k8s.agribridge.deuces.dev` while DNS was propagating, wait and run
validate again, then run the `install_platform=true` apply. The details are
in [docs/SETUP.md](../../../docs/SETUP.md).

`render-kops-terraform.sh` runs `kops update cluster --target=terraform` and
then `scripts/patch_kops_terraform.py`. The patch points the launch templates
at the AMI data source, drops the public object ACL, and removes the provider
blocks so this root can pass them in. Run the render before apply. It writes
the certificates into the state bucket, and the node configuration in
`terraform/modules/cluster` has to match those certificates.

## Existing state

`moved.tf` renames the previous root addresses into these modules. An apply
plans those moves and does not recreate the objects. `kops-state-607` and
`agribridge-oidc-237258628535` stay in the storage module. If they exist in
AWS and not in state, import them:

```sh
terraform -chdir=terraform/environments/production import module.storage.aws_s3_bucket.kops_state kops-state-607
terraform -chdir=terraform/environments/production import module.storage.aws_s3_bucket.discovery agribridge-oidc-237258628535
```

`scripts/apply-environment.sh` imports the zone, the two kOps buckets, and the
GitHub settings. It does not import an ACM certificate or the backup bucket
that already exist in the account. Adopt those before apply, and only when
they are missing from state:

```sh
CERT_ARN=$(aws acm list-certificates --region us-east-1 \
  --query "CertificateSummaryList[?DomainName=='agribridge.deuces.dev'].CertificateArn | [0]" \
  --output text)
if [ -n "$CERT_ARN" ] && [ "$CERT_ARN" != "None" ]; then
  terraform -chdir=terraform/environments/production import module.dns.aws_acm_certificate.app "$CERT_ARN"
fi
terraform -chdir=terraform/environments/production import module.storage.aws_s3_bucket.backups agribridge-backups-237258628535
```

The backup bucket name is `agribridge-backups-` plus the account id, unless
`backup_bucket` is set. This account's bucket is
`agribridge-backups-237258628535`. Skip an import when the object is already
in state, or when `list-certificates` returns `None`. Skip the bucket import
when that bucket is not in the account yet.

The zone used to be a data source. Remove that and import the zone. The
commands are in [docs/SETUP.md](../../../docs/SETUP.md). The Terraform state bucket
`agribridge-tfstate-237258628535` is not a resource here. Point `backend.hcl`
at it.

## Destroy

Uninstall the application, destroy the platform module while the API still
answers, delete the ExternalDNS A and TXT records, take the two kOps buckets
out of state so `prevent_destroy` does not stop the run, then
`terraform destroy -var install_platform=false`. The exact commands are in
[docs/SETUP.md](../../../docs/SETUP.md). The kOps buckets and the Terraform state
bucket stay in the account.
