# Configuration and access

## Runner

Delivery uses GitHub-hosted Ubuntu runners. Infrastructure and operations require
a dedicated **Linux x64** self-hosted runner labelled `agribridge`. Keep it outside
the target cluster so cluster destruction does not destroy its own runner. Do not
register it for untrusted pull-request jobs. Both plan and apply must use the same
absolute checkout path; the workflow verifies that path before applying a plan.

Install AWS CLI v2, kOps **1.36.2**, kubectl compatible with Kubernetes **1.36.6**,
`dig` for cluster generation. The composite action installs Python 3.13,
Helm 3.19.0 and the pinned Python dependency. Infrastructure jobs additionally
install Terraform 1.14.6; planning also installs Checkov 3.4.5. Operations do not
install or require Terraform. It requires outbound
HTTPS for GitHub, AWS, package downloads and Helm registries.

`KUBERNETES_API_CIDRS` must include that runner's stable public egress IP/VPN CIDR.
This is used in the kOps manifest rather than opening the API to all addresses.
The helper rejects broad or non-public CIDRs. AWS identity does not itself grant
network access to the Kubernetes API.

## GitHub settings

| Setting | Purpose |
|---|---|
| Variable `AWS_INFRA_PLAN_ROLE` | OIDC role for infrastructure planning and private plan-bundle storage |
| Variable `AWS_INFRA_APPLY_ROLE` | OIDC role for approved Terraform application/destruction |
| Variable `AWS_OPERATIONS_ROLE` | OIDC role for kOps credential export and maintenance |
| Variable `KUBERNETES_API_CIDRS` | Comma-separated narrow public runner/VPN CIDRs |
| Variable `DOCKERHUB_USERNAME` | Docker Hub namespace; defaults to `macroni607` |
| Secret `DOCKERHUB_TOKEN` | Image publication credential |
| Variable `DEPLOY_ENABLED` | Set `true` only when the existing platform is running, to enable staging/production deployment; unset keeps publishing independent of AWS |
| Variable `SONAR_ENABLED` | Set `true` to enforce the SonarQube gate on releases |
| Variable `SONAR_HOST_URL` | SonarQube address reachable by the delivery runner |
| Secret `SONAR_TOKEN` | SonarQube analysis credential |

Create environments `infrastructure-plan`, `infrastructure`,
`operations-staging`, `operations-production`, `staging` and `production`.
Restrict cloud environments to `main`. Configure a required reviewer for
`infrastructure`; otherwise GitHub does not pause before applying. Protect
`operations-production` as appropriate. The assessment expects automatic
application delivery; a reviewer on `production` deliberately adds a pause.
Availability of environment protection features depends on the repository/account.

The delivery and services-output jobs need permission to commit the specific
GitOps values files. If branch protection rejects the default Actions token,
configure an approved bot/GitHub App design before enabling releases. Git writes
fail rather than force-pushing over a concurrent change.

## AWS authentication prerequisites

Workflow role ARNs are deployment credentials supplied by the AWS account owner,
like the AWS profile used for the first local bootstrap. They are **not** the
existing `agribridge-pipeline` role: that older role only supports the retired
direct-Helm delivery path and lacks infrastructure permissions.

Configure each role to trust `token.actions.githubusercontent.com` with audience
`sts.amazonaws.com`, this repository and the relevant GitHub environment.
The repository previously used customized OIDC subjects containing repository
owner/repository IDs. Inspect the actual subject customization when configuring
trust; a default `repo:owner/repo:environment:name` assumption can be wrong.

| Role | Required access |
|---|---|
| Plan | Read/refresh the project's AWS resources and secret versions used by Terraform; read state; S3 state locks; write project kOps metadata during cluster generation; read/write encrypted `automation-plans/` objects |
| Apply | Terraform changes for the project's EC2/VPC, IAM/OIDC, S3, Route 53, ACM, Secrets Manager, SSM and logging resources; state and locking; plan-bundle read; kOps short-lived admin credential export |
| Operations | Read this cluster's kOps state and issue its short-lived cluster credentials; workloads use their own backup IAM role for S3 access |

Scope these deployment identities according to the account's policy. This
repository continues to define application/platform workload identities in
Terraform. No long-lived AWS key or kubeconfig is stored in GitHub secrets.

The account owner must establish these identities and the runner before the new
cloud workflows can execute. This refactor does not grant permissions or create
them through an unreviewed AWS operation.

## Infrastructure inputs and sensitive files

The workflows explicitly target account `237258628535`, region `us-east-1`, cluster
`k8s.agribridge.deuces.dev`, state bucket `agribridge-tfstate-237258628535` and kOps
store `s3://kops-state-607`. Porting to another account requires updating these
identities and the checked-in cluster/application definitions together.

`terraform/terraform.tfvars.example` documents root service inputs. The workflow
supplies the discovery bucket and account guard automatically. Platform inputs
come from Terraform outputs; environment runtime references come from SSM. Do not
copy secret values between files or pass them as image build arguments.

Private plan bundles are stored under the state bucket's `automation-plans/`
prefix with S3 encryption and a seven-day lifecycle rule. They include the saved
plan, readable plan, JSON plan and generated cluster configuration where needed.
They exclude runner kubeconfigs. Reviewers need authorized S3 access; GitHub's
summary contains resource-action counts and the bundle location, not secret values.
The lifecycle rule takes effect after the next approved bootstrap apply.


## Infrastructure workflow layout

`infrastructure.yaml` contains named actions only: select state, generate cluster
input, verify the cluster session, save and scan the plan, store private evidence,
then apply after environment approval and verify the result. Shared actions call
`.github/ci/infrastructure.py`, which holds the tested state, plan and bundle logic.
The apply job verifies the bundle hash and workspace, then applies the original
binary plan without replanning. Plan/report contents stay out of public logs.

Main delivery, infrastructure and operations share `agribridge-cloud-maintenance`.
Do not dispatch multiple maintenance requests while another is pending: GitHub's
concurrency model retains only one pending run in a group. Separate dev/PR groups
let read-only checks proceed independently of cloud maintenance.

The operations workflow also contains named actions only: validate the request,
open a verified session, run the selected health/backup/isolated restore/resilience
task, retain evidence and clean up. `.github/ci/operations.py` centralizes these
commands and enforces environment guards before cluster operations. The helper
uses existing Helm resources; it does not install Terraform or provision AWS.
