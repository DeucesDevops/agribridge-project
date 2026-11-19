# Terraform

This root creates the environment. The cluster itself is the Terraform kOps
writes into `kops/` from `kops/cluster.yaml`.

| File | What it creates |
|---|---|
| `kops/kubernetes.tf` | VPC, instances, security groups, kOps IAM, issuer, node configuration objects |
| `cluster.tf` | The module call for that output |
| `dns.tf` | Public Route 53 zone, ACM certificate, validation records |
| `buckets.tf` | kOps state bucket, OIDC discovery bucket, private backup bucket |
| `secrets.tf` | Production and Grafana secrets |
| `iam.tf` | GitHub Actions role, and IRSA for External Secrets, ExternalDNS and backups |
| `github.tf` | Actions variables and the `production` environment |
| `platform.tf` | Helm releases, on the second apply |
| `modules/platform` | External Secrets, ExternalDNS, Loki, Tempo, Prometheus, Grafana, Promtail |

kOps also installs the AWS Load Balancer Controller, the EBS CSI driver and
the pod-identity webhook. The launch templates have no SSH key. `sshAccess`
in the cluster spec is empty. The API security group allows 443 from the
internet so GitHub-hosted runners can deploy. Authentication is still required.

Grafana is `https://grafana.<zone>` on the same load balancer, with anonymous
access off. The admin password is `agribridge/grafana` in Secrets Manager.

Deploy jobs run `kops export kubeconfig --admin`. The admin credential is in
the kOps state bucket. The GitHub role can read that bucket. That is
cluster-admin access, and it is the reason the pipeline does not need a
kubeconfig secret or SSH.

## What stays outside this root

The Terraform state bucket is created by `scripts/bootstrap-state.sh`.
Terraform stores its state there, so it cannot create that bucket itself.
The bucket is versioned, encrypted and private. State holds the generated
passwords. That is why the bucket is not in git. It is not `kops-state-607`.

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
terraform apply -var install_platform=false
kops export kubeconfig --admin --name k8s.agribridge.deuces.dev
kops validate cluster --wait 15m
terraform apply -var install_platform=true
```

`render-kops-terraform.sh` runs `kops update cluster --target=terraform` and
then `scripts/patch_kops_terraform.py`. The patch points the launch templates
at the AMI data source, drops the public object ACL, and removes the provider
blocks so this root can pass them in. Run the render before apply. It writes
the certificates into the state bucket, and the node configuration in
`terraform/kops` has to match those certificates.

## Existing state

`kops-state-607` and `agribridge-oidc-237258628535` stay in this root. If
they are already in the state file, leave them there. If they exist in AWS
and not in state, import them:

```sh
terraform import aws_s3_bucket.kops_state kops-state-607
terraform import aws_s3_bucket.discovery agribridge-oidc-237258628535
```

The zone used to be a data source. Remove that and import the zone. The
commands are in [docs/SETUP.md](../docs/SETUP.md). The Terraform state bucket
`agribridge-tfstate-237258628535` is not a resource here. Point `backend.hcl`
at it.

## Destroy

Uninstall the application, destroy the platform module while the API still
answers, delete the ExternalDNS A and TXT records, take the two kOps buckets
out of state so `prevent_destroy` does not stop the run, then
`terraform destroy -var install_platform=false`. The exact commands are in
[docs/SETUP.md](../docs/SETUP.md). The kOps buckets and the Terraform state
bucket stay in the account.
