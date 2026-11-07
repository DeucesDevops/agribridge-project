# Reproduce AgriBridge

The commands below are instructions for a future authorized deployment. The
workflow refactor was prepared without creating AWS resources.

## 1. Local verification

Install Node.js, Docker, Terraform, Helm and Python. From the repository root:

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r scripts/requirements.txt
npm ci --prefix api
npm ci --prefix frontend
make check
cp .env.example .env
make local
```

Browse http://localhost:8080, then run `make local-verify` to verify a separate
disposable stack. `make stop` stops your development stack while retaining data.
Local files contain throwaway development credentials only.

## 2. Establish cloud automation access

Publish the reviewed workflow changes to `main`, provision/register the dedicated
runner and configure the AWS roles and GitHub settings in
[CONFIGURATION.md](CONFIGURATION.md). These credentials are account-level bootstrap
prerequisites. Do not substitute the retired deployment role.

For a completely new account, the state bucket must exist before a remote backend
can use it. Run the bootstrap Terraform configuration once using the account
owner's authorized local AWS profile:

```sh
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap plan -out=bootstrap.tfplan
terraform -chdir=terraform/bootstrap apply bootstrap.tfplan
aws s3 cp terraform/bootstrap/terraform.tfstate \
  s3://agribridge-tfstate-237258628535/bootstrap/terraform.tfstate \
  --sse AES256 --only-show-errors
```

For this existing project, bootstrap resources and a recovery state may already
exist. **Do not run a fresh bootstrap apply over retained resources.** Recover and
verify the authoritative state first. The workflow refuses to proceed if the
existing bootstrap S3 key cannot be read. DNS delegation from the parent zone must
point at the project zone's Terraform outputs before cluster generation.

Once workflows own bootstrap state, that S3 key is authoritative and locked.
The old workstation copy becomes stale. For a later local bootstrap operation,
configure the same S3 backend override and initialize against that key before
planning; never apply the stale local state.

## 3. Provision infrastructure in dependency order

In GitHub Actions select **Infrastructure — plan, apply or destroy** and dispatch
from `main`. Select one stage at a time:

| Stage | What should exist afterward |
|---|---|
| `bootstrap` | State/discovery storage, existing project DNS and private plan retention |
| `cluster` | VPC, nodes and ready kOps controllers |
| `services` | Runtime secrets, TLS, IAM, backups/logs and current SSM metadata |
| `platform` | Namespaces, storage, ingress, monitoring, logging, Argo CD and Applications |

Choose `action=plan` for a preview. Choose `action=apply` for a run that generates
its own saved plan, stores its bundle privately, and waits at the protected
`infrastructure` environment. Download the indicated bundle through authorized
AWS access, inspect `plan.txt`, then approve that run. The apply job verifies the
bundle checksum and uses that exact binary plan. It does not regenerate the plan.
Terraform rejects a stale plan if state changed while approval was pending.

Cluster planning updates the kOps metadata in S3 and generates Terraform input;
it does not apply cluster infrastructure. The kOps compatibility fix remains in
the generated input so a cold bootstrap does not deadlock its admission webhook.

Services application automatically refreshes the non-secret Argo CD values from
SSM and commits them to `main`, preserving image selections. Platform installation
enables Argo CD. No outputs are copied manually into Helm values.

The CLI equivalent of selecting a stage is:

```sh
gh workflow run infrastructure.yaml --ref main -f stage=cluster -f action=apply
```

## 4. Release the application

Merge application changes into `main` or dispatch `delivery.yaml`. The jobs are
`checks → publish → staging → production`; a failed prerequisite blocks later jobs.
Checks include real PostgreSQL integration tests, API and frontend coverage,
lockfile integrity, linting, build checks and report publication. SonarQube adds
its configured quality gate before publication.

The published images are the images exercised by Compose in CI. Actions commits
their immutable digests to staging. Argo CD reconciles the application chart;
HTTPS/readiness/build-identity checks must pass before those same digests are
promoted to production.

For a SonarQube-only validation run:

```sh
gh workflow run delivery.yaml --ref main -f analysis_only=true
```

That run requires SonarQube connection settings and executes checks/analysis,
without publishing or deploying images.

## 5. Verify operations and capture evidence

Dispatch `operations.yaml` with `task=check` for both environments. Run a backup,
an isolated restore test using its S3 key, and the staging-only resilience task.
Capture workflow URLs and non-secret results in `docs/evidence/`. See
[OPERATIONS.md](OPERATIONS.md) for exact task inputs and cleanup order.

Record live results separately from local validation. The new cloud workflows
are prepared source until they have actually run successfully with the configured
runner and AWS identities.
