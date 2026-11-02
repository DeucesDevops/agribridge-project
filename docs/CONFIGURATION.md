# Configuration checklist

Use this alongside [the ordered rebuild guide](REBUILD-GUIDE.md). Complete this
checklist before running infrastructure provisioning. Values below describe the
working AgriBridge baseline; substitute your own project identity for another app.

## 1. What you supply, in order

| When | Supply or decide | Where it goes | Secret? |
|------|------------------|---------------|---------|
| Before local work | Node, Docker, Terraform, kOps, kubectl, Helm, AWS CLI, GitHub CLI, jq, Python/PyYAML | Your workstation | No |
| Before AWS provisioning | An authenticated AWS operator profile with permissions for the project's resources | AWS CLI's normal profile/SSO mechanism | Credentials stay outside Git |
| Before AWS provisioning | Region, two availability zones, cluster name, state-bucket identity and domain | Terraform Terraform inputs, cluster YAML and provisioning scripts below | No |
| Before DNS-dependent provisioning | Control of the parent domain; delegate the project's public hosted zone | Parent DNS provider, using Route 53's name servers | No |
| Before GitHub provisioning | Repository with HTTPS origin, default branch, authenticated `gh` access | Git remote and GitHub CLI | GitHub authentication stays outside Git |
| Before image publication | Docker Hub account and repositories available for push/pull | Registry settings below | Username is public |
| Before image publication | Docker Hub token with push access to the two application repositories | GitHub Actions repository secret `DOCKERHUB_TOKEN` | Yes |
| Before local Compose | Throwaway local DB, signing and demo passwords | Ignored root `.env`, copied from `.env.example` | Local-only |
| Before Kubernetes deployment | Replica counts, resources, database size, runtime settings and seeding policy | Helm values | No secret values |
| Before operating | Monitoring retention, backup schedule/retention and recovery objectives | Monitoring values, Helm backup values and backup module | No |

AWS permissions must cover the resources in the Terraform modules: networking and
EC2/Auto Scaling, S3/state locks, Route 53, IAM/OIDC, ACM, ECR for the retained legacy
repositories, SSM, CloudWatch, EventBridge and SQS. The workstation also needs access
to the kOps state bucket to create/export cluster credentials. The GitHub release
role is separate and intentionally has much narrower deployment permissions.

## 2. Workstation and account setup

The baseline uses Node 22.22.0, Terraform 1.14.6 in CI (root requirement >=1.10),
kOps 1.36.2, Kubernetes 1.36.6 and Helm >=3.19. Docker Desktop must be running for
local Compose. Install Python 3 with PyYAML for the provisioning helpers. Install
Git, AWS CLI v2, kubectl, GitHub CLI and jq as well.

Verify authentication and tool availability before provisioning:

```sh
node --version
docker version
terraform version
kops version
kubectl version --client
helm version
gh auth status
aws sts get-caller-identity
python3 -c 'import yaml; print(yaml.__version__)'
```

If you use a named AWS profile, export `AWS_PROFILE` in your own terminal before
running the scripts. For SSO accounts, sign in through your configured SSO profile.
Do not put AWS access keys into project files or GitHub Actions. The prepared
GitOps application workflow uses GitHub repository permissions and a Docker Hub
token; it does not connect to the Kubernetes API or assume an AWS deployment role.
Runtime workloads use the cluster OIDC identity.

For another repository, set its HTTPS origin before provisioning:

```sh
git remote set-url origin https://github.com/YOUR-OWNER/YOUR-PROJECT.git
```

The scripts derive the owner/repository from that origin. Their current parsing
expects an HTTPS GitHub remote.

## 3. Project identity: the values you must align

This is a working project blueprint with literal AgriBridge names in several
files. For another project, update all related entries before its first apply.
Moving the repository into a differently named directory does not configure them.

| Setting | AgriBridge value | Files to review/change |
|---------|------------------|------------------------|
| Project/resource prefix | `agribridge` | Hand-written Terraform module resource names/strings, provisioning/deployment scripts, Helm values and workflow image names |
| Public hosted zone | `agribridge.deuces.dev` | Bootstrap configuration and AWS service configuration variables; `kubedefs/cluster.yaml`; provisioning/operating scripts and workflow environment URLs |
| Cluster name | `k8s.agribridge.deuces.dev` | Cluster YAML metadata and labels; AWS service configuration variables; provision/resume scripts |
| Kubernetes API DNS | `api.k8s.agribridge.deuces.dev` | Cluster YAML `masterPublicName`; deploy kubeconfig construction in `modules/kubernetes-platform/main.tf` |
| kOps state bucket | `kops-state-607` | Bootstrap configuration input; cluster YAML `configBase`; provision/resume scripts, including bootstrap adoption logic |
| Terraform state bucket | `agribridge-tfstate-ACCOUNT_ID` | `modules/bootstrap/main.tf` and provision/resume backend construction |
| OIDC discovery bucket | `agribridge-oidc-ACCOUNT_ID` | Bootstrap module and scripts; the script supplies the account-specific value to cluster YAML and AWS service configuration |
| Region | `us-east-1` | Terraform inputs; cluster configuration provider configurations; cluster zones; AWS CLI flags in scripts; GitHub workflow |
| Availability zones | `us-east-1a`, `us-east-1b` | Cluster subnets and instance groups in `kubedefs/cluster.yaml` |
| Docker Hub username | `macroni607` | AWS service configuration `dockerhub_username`; workflow fallback username |
| Docker Hub repositories | `agribridge-api`, `agribridge-web` | `modules/registry/outputs.tf` and workflow publishing identities |
| Helm release | `agribridge` | Deploy/render scripts; scripts' workload names; default `PGHOST` and `REDIS_URL` in Helm values |
| Environments | `staging`, `production` | AWS service configuration inputs, Kubernetes platform namespace set, Helm environment values, workflow jobs and script environment guards |
| NLB name | `agribridge-ingress` | Flat NGINX values template under `kubedefs/` |
| Runtime secret names | `agribridge-staging/runtime-v2`, `agribridge-production/runtime-v2` | Root `runtime_secret_names` map, runtime-secrets module and derived SSM handoff; old names remain scheduled for deletion |
| Deployment secret names | `agribridge-staging/deploy`, `agribridge-production/deploy` | Kubernetes platform module, IAM scope and SSM handoff |
| Namespace names | `agribridge-staging`, `agribridge-production` | Kubernetes platform module, handoff configuration and operating scripts |
| Log group | `/agribridge/containers` | Observability module and Fluent Bit values |
| Backup bucket/prefixes | `agribridge-backups-ACCOUNT_ID`; `staging/`, `production/` | Backup module, deployment handoff and Helm backup values |

Find remaining project-specific references in authored files:

```sh
rg -n 'agribridge|deuces\.dev|kops-state-607|macroni607|us-east-1' \
  terraform kubedefs scripts helm monitoring .github
```

Generated cluster code also contains account/domain values. Regenerate it with kOps
for the new identity/account; do not globally replace strings in generated policies
or launch templates. Use fresh state and unique buckets for a different project;
never copy this project's state, `.runtime` directory or kubeconfig into it.

## 4. Terraform inputs to enter

Each Terraform entry point accepts inputs through its `variables.tf`. Non-secret local
settings may be put in an ignored `project.auto.tfvars` inside that folder.

Example for `terraform/bootstrap/project.auto.tfvars`:

```hcl
region            = "us-east-1"
zone_name         = "agribridge.deuces.dev"
kops_state_bucket = "kops-state-607"
```

Example for `terraform/project.auto.tfvars`:

```hcl
region             = "us-east-1"
zone_name          = "agribridge.deuces.dev"
cluster_name       = "k8s.agribridge.deuces.dev"
dockerhub_username = "macroni607"
environments       = ["staging", "production"]
```

For a different project, use its new values and align the literal identifiers in
section 3. The provisioning scripts also supply certain arguments explicitly;
keep their names/region/buckets consistent with these inputs.

| Input | Who supplies it |
|-------|-----------------|
| AWS account ID | Read from STS by provisioning, not typed into secrets |
| `discovery_bucket` | Provisioning script derives the account-specific bucket |
| `repository_subject_prefix` | Script reads GitHub's OIDC customization API for the current repository |
| `platform` map | AWS service configuration outputs, written automatically into a private runtime input file |
| `kubeconfig_path` | Script exports an admin kubeconfig and passes its absolute path |
| ACM ARN, secret ARNs, image URLs, backup role/bucket | Terraform outputs → SSM → deployment script |

Do not copy the current repository's numeric owner/repository IDs into another
repository's IAM trust. Use the script's discovered subject prefix. kOps workload
identity uses audience `amazonaws.com`; GitHub Actions uses its own issuer with
`sts.amazonaws.com`.

Remote state keys remain `kops/terraform.tfstate`, `services/terraform.tfstate` and
`platform/terraform.tfstate`. Bootstrap keeps local state plus an encrypted S3
recovery copy. The folder simplification does not change those keys. Initialize
from the documented entry-point paths rather than creating a replacement backend.

## 5. Cluster configuration

Edit only `kubedefs/cluster.yaml` for cluster shape. Check:

- Cluster metadata, matching labels, API hostname, DNS zone and `configBase`.
- Kubernetes version, the Ubuntu image for each instance group, region and zones.
- Network CIDR and subnets: the baseline uses `172.20.0.0/16` across two public subnets.
- One control plane and two worker groups, each currently `t3.medium`; this is not an HA control plane.
- Calico networking, EBS CSI, AWS Load Balancer Controller and pod identity enabled.
- No SSH access. Scope Kubernetes API access to the operator/runner networks you will actually use.

The provisioning script sets the OIDC discovery bucket using the detected account.
It regenerates `terraform/generated/kops/`, prepares the module and applies the
bootstrap webhook fix before running cluster configuration.

## 6. DNS and TLS sequence

1. Create/adopt the public hosted zone through bootstrap configuration.
2. Read its name servers after applying:

   ```sh
   terraform -chdir=terraform/bootstrap output -json name_servers
   ```

3. Delegate that subdomain from the parent DNS provider. For this project it is
   `agribridge.deuces.dev`, not the whole `deuces.dev` domain. Preserve existing
   mail and unrelated DNS records.
4. Confirm public DNS resolution before the cluster/API and ACM-dependent stages.
5. AWS service configuration requests and validates the apex/wildcard ACM certificate.
6. Platform configuration installs NGINX, whose Service requests the AWS NLB. After its hostname
   exists, Terraform creates staging/production CNAME records.

The flat `kubedefs/nginx-ingress-values.yaml.tftpl` supplies the controller class,
replicas and NLB behavior. Terraform inserts the ACM ARN. Public HTTPS 443 terminates
at the NLB and targets NGINX HTTP 80; public port 80 is disabled. Instance targets
are used with Calico. No manual AWS-console load balancer is required.

## 7. GitHub and Docker Hub configuration

| Item | Where | Provided by |
|------|-------|-------------|
| `DOCKERHUB_TOKEN` | GitHub repository → Settings → Secrets and variables → Actions → Secrets | You; reuse an existing valid push token where appropriate |
| `DOCKERHUB_USERNAME` | GitHub Actions repository variable | Provisioning script, from the registry namespace output |
| `AWS_DEPLOY_ROLE` | Legacy repository variable | Unused by the prepared GitOps workflow |
| `staging`, `production` environments | GitHub repository environments | Provisioning script |
| Git write permission | Staging/production workflow jobs | Scoped `GITHUB_TOKEN` with contents: write |
| Kubernetes API access for CD | Argo CD inside the cluster | Terraform-installed controller, scoped AppProject destinations |
| Legacy deployment kubeconfigs | Disabled for this rebuild | `enable_legacy_pipeline = false`; no CI deployment tokens created |

Use public Docker Hub repositories for this baseline: the chart has no private
registry pull-secret configuration. A private registry requires adding and managing
its runtime image-pull credentials before deployment.

The workflow has four jobs: checks → publish → staging → production. It builds once,
publishes verified images, commits their digests to staging values and waits for
Argo CD's deployment to pass HTTPS readiness/build-identity checks. Production
copies the same digests after that gate. Production environment review rules, when
configured, apply before promotion. Main must permit the reviewed CI bot writes;
`make check-delivery` checks this before publication. Application-source pushes
to `main` and manual dispatch on `main` can publish; pull requests run checks.
Image-values-only bot commits do not loop into new image builds. Infrastructure
provisioning stays outside this workflow. See `argocd/README.md` for first bootstrap.

## 8. Runtime configuration and secrets

| Concern | Authoritative configuration |
|---------|-----------------------------|
| Shared non-secret application settings | `helm/agribridge/values.yaml` |
| Staging replicas and demo seed hook | `helm/agribridge/values-staging.yaml` |
| Production replicas and no demo seeding | `helm/agribridge/values-production.yaml` |
| API/frontend repositories, hostname and AWS identifiers | `make prepare-gitops` consumes Terraform-published non-secret SSM metadata into `argocd/*-values.yaml` |
| Image tag and digest | CI records actual pushed digests in the environment GitOps values; production copies staging |
| `PGPASSWORD`, `JWT_SECRET`, `SEED_PASSWORD` in AWS | Terraform-generated random values in per-environment Secrets Manager JSON entries |
| Secret delivery | External Secrets resolves those entries into the namespace's runtime Secret |
| Build identity | CI supplies `APP_VERSION`, `GIT_SHA`, `BUILD_DATE`, `IMAGE_TAG` as Docker build arguments |

You do not manually enter the deployed database/JWT/demo password values. Terraform
creates them. The JSON shape is three keys: `PGPASSWORD`, `JWT_SECRET`, `SEED_PASSWORD`.
No real values belong in Helm values, Docker build arguments or Git.

Review these Helm settings when adapting the application:

| Settings | Baseline |
|----------|----------|
| Process | `NODE_ENV=production`, API port 3000, log level info, shutdown grace 10000 ms |
| Database | Service `agribridge-postgres`, port 5432, database/user `agribridge`, internal `PGSSL=false`, pool max 10 |
| Cache | Redis enabled, service URL `redis://agribridge-redis:6379`, optional at runtime, TTL 30 s |
| Authentication | Secure cookies, TTL 28800 s, bcrypt rounds 12 |
| Startup | Migrations enabled with advisory locking; regular API pods do not seed |
| Persistence | Encrypted gp3 via `agribridge-gp3`, PostgreSQL claim 20 GiB per environment |
| Health | Root `/healthz` for startup/liveness, `/readyz` for readiness, `/metrics` for scraping |
| Browser routing | Relative `/api` calls; frontend Nginx proxies them at runtime under the same HTTPS origin |

For local Compose only, copy root `.env.example` to `.env` and choose disposable
values for its three password/signing fields. Local HTTP uses insecure cookies by
explicit Compose configuration. `api/.env.example` documents standalone API options;
it is not the deployed secret-delivery mechanism.

## 9. Monitoring, backups and optional decisions

| Setting | File | Current baseline |
|---------|------|------------------|
| Prometheus retention/storage | `monitoring/prometheus-values.yaml` | 7 days / 10 GiB |
| Grafana persistence | Same file | 2 GiB |
| Logs destination | `monitoring/fluent-bit-values.yaml.tftpl` and observability module | CloudWatch `/agribridge/containers`, 14 days |
| Application metrics/rules | `helm/agribridge/templates/monitoring.yaml` | ServiceMonitor and unavailable alert |
| Database backup schedule | Helm values `backup.schedule` | Daily at 02:00 UTC |
| Backup storage retention | `terraform/modules/backups/main.tf` | Current objects 30 days, old versions 7 days |
| Dashboard access | Operations guide | Local port-forwards; not public Ingresses |
| External alert delivery | Alertmanager configuration | No recipient/destination configured |

Choose recovery-point/recovery-time objectives and test an isolated restore before
claiming recovery works. Retained EBS volumes and state/backup buckets need explicit
retention decisions during teardown; do not delete them merely to make a destroy
finish. Application account onboarding is also a separate decision: production
starts without demo users, and the supplied application has no public registration.
