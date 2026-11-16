# Configuration and access

## Where each task runs

| Task | Tool and location |
|---|---|
| Local application | Docker Compose on your computer |
| Infrastructure | Terraform CLI on the existing `kops` management instance |
| Cluster credentials | Short-lived `kops export kubeconfig --admin=1h` in your terminal |
| Application CI/CD | GitHub-hosted runners and Argo CD |
| Maintenance | kubectl and Helm from an authorized terminal |

Use standard Ubuntu; no Ubuntu Pro subscription or self-hosted Actions runner is
required. The full command sequence is in [REPRODUCTION.md](REPRODUCTION.md).

## GitHub settings

| Setting | Purpose |
|---|---|
| Variable `DOCKERHUB_USERNAME` | Docker Hub namespace; defaults to `macroni607` |
| Secret `DOCKERHUB_TOKEN` | Image publication credential |
| Variable `DEPLOY_ENABLED` | `true` enables staging/production delivery; keep false during infrastructure maintenance |
| Variable `SONAR_ENABLED` | `true` enforces SonarQube on main releases |
| Variable `SONAR_HOST_URL` | SonarQube URL reachable by the GitHub runner |
| Secret `SONAR_TOKEN` | SonarQube analysis credential |

Use GitHub environments `staging` and `production`. Require the stable `checks`
result before merging `dev` → `main`. A production environment reviewer adds an
intentional promotion pause. Fast-forward `dev` after a merge; never rewrite it.
Automated release commits retain the GitHub Actions bot identity.

Delivery commits only GitOps release selections. If branch protection blocks its
Actions token, configure an approved bot/App before enabling delivery. Writes
fail on concurrent changes instead of force-pushing.

The retired infrastructure/operations workflows and their runner/OIDC role
prerequisites are no longer used. Do not create new cloud automation roles for
them. Any existing unused runner registration or IAM roles should be reviewed
separately before removal; this source change does not alter account access.

## AWS and Kubernetes access

Use your existing authorized AWS identity in account `237258628535`, region
`us-east-1`. Terraform uses its standard credential chain. Do not store AWS keys,
kubeconfigs or runtime passwords in GitHub secrets or Git.

The Kubernetes API allows narrow public administrator/VPN CIDRs supplied through
`AGRIBRIDGE_API_CIDRS` when generating the cluster. Include the management host's
current public egress address. An AWS login does not grant Kubernetes network
access. The helper rejects missing, private or broad CIDRs.

Workload identities remain separate: External Secrets reads Secrets Manager,
backup Jobs write S3, and Fluent Bit writes CloudWatch using their existing
scoped roles. CI/CD updates Git and needs no AWS or Kubernetes credentials.

## State, inputs and private files

All roots use the existing bucket `agribridge-tfstate-237258628535` with encryption
and S3 lockfiles. Each root has its own existing key; see `terraform/README.md`.
`terraform/backend.hcl.example` contains shared non-secret settings.

The bootstrap root now declares its remote backend directly. If an older workflow
left an ignored `terraform/bootstrap/backend_override.tf`, move it outside that
root before initializing. Never apply a stale local bootstrap state over the
remote recovery key. If state is missing or inaccessible, recover it first.

Copy `terraform/terraform.tfvars.example` to `.runtime/services.tfvars` for service
inputs. Platform inputs come from services outputs; non-secret GitOps references
come from SSM. Keep `.runtime/` private: plans and state may contain passwords.
Apply the exact saved plan you reviewed; regenerate and review if it becomes stale.

Provider lockfiles contain verified macOS and Linux amd64 checksums. Initialization
uses `-lockfile=readonly`; record verified hashes before adding a new platform.

## DNS and HTTPS

Namecheap hosts `deuces.dev` and delegates only `agribridge.deuces.dev` to the
existing Route 53 child zone. Terraform manages ACM validation and environment
CNAME records there. The management instance IP is not an application endpoint.
See [DNS.md](DNS.md) for the verified records and ownership.
