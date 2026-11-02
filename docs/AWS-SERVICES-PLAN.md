# AWS services preparation — 2 November 2026

The cluster apply and readiness checks passed. Bernard's refreshed cluster plan
reported `No changes. Your infrastructure matches the configuration.` The next
batch prepares AWS services consumed by the Kubernetes platform and application.
Bernard applied the reviewed services plan successfully: **33 added, 0 changed,
0 destroyed**. Independent AWS verification passed; see the completion record
below. Kubernetes platform installation remains pending its own reviewed plan.

## Prepare the review artifact

From the project root in the normal terminal:

```sh
make plan-services
```

The command checks account `237258628535`, initializes the existing services
backend boundary at `services/terraform.tfstate`, validates configuration and
saves a binary plan plus readable text under the ignored `.runtime` directory.
If a remote services state already exists, it saves a private recovery copy.
Failure to list or pull state stops execution. The first run legitimately has
no existing services state; a read-only AWS check confirmed that key was absent.

It does not apply resources, restore secrets, install Kubernetes components or
write GitHub settings. Planning makes normal provider/backend reads and may
write a temporary Terraform state lock in S3. Review the actual saved plan before
any apply; source resource counts are not a substitute for a provider-backed plan.

## Intended scope

| Component | Planned purpose |
|---|---|
| Two runtime secrets and fresh random credentials | PostgreSQL password, session signing and seed credentials for staging and production |
| External Secrets IAM role | Read only the two newly managed runtime secrets from the designated service account |
| Backup bucket, retention and per-environment IAM | Private, encrypted, versioned backups with 30-day current-object retention and seven-day noncurrent retention |
| ACM certificate and DNS validation | `agribridge.deuces.dev` and its wildcard, validated through the existing hosted zone |
| CloudWatch log group and workload role | Container logs with 14-day retention |
| Node SSM policy attachment | AWS Systems Manager permissions for the cluster worker role |
| SSM deployment parameters | Non-secret environment handoff including secret ARNs and Docker Hub image names |
| GitHub OIDC provider and narrow pipeline role | AWS identity for later reviewed delivery configuration; no GitHub settings are written |

The source currently describes 33 managed resources including six local random
password resources. Obtain actual actions from the plan. Application PVCs,
ingress load balancer, External Secrets installation, monitoring installation and
application releases belong to later separately reviewed platform/application
changes. This command does not deploy them.

## Rebuild decisions

Read-only AWS metadata still lists the old staging and production `/runtime`
and `/deploy` secrets as marked for deletion. No secret values were fetched.
The new root `runtime_secret_names` defaults select:

- `agribridge-staging/runtime-v2`
- `agribridge-production/runtime-v2`

Terraform generates fresh values only on apply. The runtime-secrets module's
resource addresses remain unchanged; the root passes explicit names and all
consumers receive the resulting ARNs through Terraform outputs. Old secret
deletion remains scheduled; no restore, import or force deletion is proposed.
Review these names with the saved plan before approving creation.

The account contains no ECR repositories. The registry module now makes legacy
ECR management optional and disabled by default (`manage_legacy_ecr = false`),
so the new Docker Hub rebuild does not recreate unused repositories. Its Docker
Hub image outputs remain unchanged. Existing users retaining ECR must explicitly
enable that module input before planning against a state that owns those
repositories; disabling management against such a state would propose deletion.
This rebuild's services state is absent, so no existing ECR state is being removed.

## Review and verification

The AWS provider now checks the expected account at the services entry point,
matching bootstrap and cluster protections. Before apply, review exact actions,
IAM trust, the GitHub repository subject, secret names, certificate validation,
incremental costs and any unexpected existing resources.

Shell syntax, Terraform formatting and whitespace checks passed. A temporary
command-stub harness exercised fresh and existing state, account mismatch,
access denial, validation failure and failed state backup. It verified no apply,
import or destroy invocation. The local provider schema handshake remains blocked
in the agent session, so provider-backed validation and planning must run in the
normal terminal. Do not replace the provider binaries based on that limitation.

Saved plans and state may contain sensitive values. Keep artifacts private under
`.runtime` and share the final summary for review. Do not run `make provision` or
`make resume` during this staged process; both apply additional infrastructure.

## Saved plan reviewed — 2 November 2026, 13:16 UTC

The normal-terminal run produced:

- Plan: `.runtime/services-20261102T131616Z-51878.tfplan`.
- Readable review: `.runtime/services-20261102T131616Z-51878.txt`.
- SHA-256: `7a82746aba8e5d9f4be147bc9bdb13d8b082a9a48c9e0f326c93ba4ae7a1f8d9`.
- **33 additions, 0 changes, 0 deletions**; no warnings in the saved readable
  output. Six additions are local random password resources.

The configuration embedded in the binary plan matches all current root/module
source files. Resource types and names match the intended scope above. No EC2,
NAT gateway, load balancer, ECR repository or Kubernetes resource is included.

The backup bucket blocks all public access, uses AES256 encryption and versioning,
and has the expected retention rules. Log retention is 14 days. Both runtime
secret names end in `/runtime-v2`; each has a 30-day deletion recovery window.
The ACM certificate covers the base and wildcard domains and uses DNS validation
in current zone `Z098670523YNOQ1LDBYDG`.

Workload IAM trust uses the current cluster OIDC issuer, audience `amazonaws.com`
and explicit service accounts. Policies computed after apply were reviewed in
the matching embedded source: External Secrets reads only managed secret ARNs;
backup roles access their environment prefix; logging writes to the project log
group. The worker role receives AmazonSSMManagedInstanceCore. GitHub trust uses
`sts.amazonaws.com` and exact staging/production environment subjects for the
configured repository prefix. Read-only GitHub metadata confirms owner ID
`132962088` and repository ID `1409286862`, matching the configured prefix. The
actual workflow token and OIDC subject settings still require runtime verification
during delivery setup; creating this role does not establish a working pipeline.
The retained pipeline policy can read project deployment secrets; no such secret
is restored or created in this batch, and direct Helm delivery still awaits the
later GitOps ownership change.

### Incremental costs

Two stored secrets at $0.40/secret-month add approximately **$0.80/month**
(prorated for time stored), plus $0.05 per 10,000 Secrets Manager API calls.
S3 backup storage/requests and CloudWatch log ingestion/storage add usage charges.
The planned public ACM certificate uses the default non-exportable mode for an
ACM-integrated load balancer and has no additional certificate charge. The future
load balancer itself is outside this plan and has its own cost. Existing cluster
and hosted-zone charges continue separately. Taxes and account-specific credits
are excluded; $0.80 is not a cap on the services bill.

Prices verified on 2 November against official
[Secrets Manager pricing](https://aws.amazon.com/secrets-manager/pricing/) and
[ACM pricing](https://aws.amazon.com/certificate-manager/pricing/).

### Apply decision

Bernard approved this stage by executing the exact command below in the normal
terminal. The command is retained as the apply record; do not repeat this
creation plan now:

```sh
terraform -chdir=terraform apply -input=false \
  "$PWD/.runtime/services-20261102T131616Z-51878.tfplan"
```

No additional variables are needed when applying the saved plan. Do not apply a
different artifact without review. After completion, verify secret metadata
without reading values, bucket protections, certificate issuance, IAM scope and
a fresh no-change services plan before proceeding to the Kubernetes platform.

## Completion verified — 2 November 2026

Bernard supplied the full successful apply transcript. Read-only AWS APIs verified:

- Both `/runtime-v2` secrets exist, are active and have AWSCURRENT versions. No
  secret values were fetched or printed.
- ACM certificate `af2e5092-e3e6-4438-a04c-bc586f3671a3` is ISSUED, covers the
  base and wildcard names, and has export disabled.
- Backup bucket versioning, AES256 encryption, all four public-access blocks,
  30-day expiration and seven-day noncurrent retention match the plan.
- The five IAM trust policies and inline policies match the reviewed scope;
  External Secrets reads only the two new secret ARNs, backup roles access their
  own prefix, logging writes to the project log group, and GitHub trust is
  limited to the reviewed staging/production environment subjects.
- The worker role has AmazonSSMManagedInstanceCore attached.
- Both deployment parameters are Standard String parameters. Their values were
  not fetched; the Terraform source defines non-secret deployment metadata.
- The project log group has 14-day retention. Remote services state metadata
  shows a write at `2026-11-02T13:27:03Z`.

The refreshed no-change services check is included as a prerequisite in
`make plan-platform`. That command stops on proposed changes or errors and saves
the no-change check output. A services apply is not proof that application or
platform Helm releases have been installed.
