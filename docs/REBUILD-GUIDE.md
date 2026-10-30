# Rebuild this project, step by step

Use this as the ordered learning path for AgriBridge or as a blueprint for another
project. Read [CONFIGURATION.md](CONFIGURATION.md) before entering values. Commands
run from the repository root unless a command says otherwise. This guide describes
the checked-in baseline; it does not mean every operational acceptance test has
already passed. See [VERIFICATION.md](VERIFICATION.md) for actual evidence.

## How to use this in future chats

Open one new chat per numbered stage, using its title and starter prompt below.
Attach or open the target repository in that chat. Paste this context before the
stage-specific prompt:

> I am following docs/REBUILD-GUIDE.md and docs/CONFIGURATION.md. Work in this
> repository, inspect its current files and verification notes first, and help me
> complete the selected stage. Explain the inputs, make the changes, run suitable
> checks, and record evidence and remaining work. Reuse existing resources and
> state when continuing this project. For a different project, use its own identity
> and fresh state. Keep credentials out of Git and chat output. Finish at the
> stage's completion check and tell me which stage follows.

The stages are preparation, infrastructure, delivery, then operation. Stages 05–08
are the four infrastructure stacks. `make provision` orchestrates them together;
do not run it four times as if each stage needed a separate full provisioning.
For a fresh DNS zone, complete bootstrap and delegation in stage 05 first, then
run it once. It reapplies bootstrap idempotently before continuing. Provisioning
applies changes automatically, so review identity, costs and plans first.

| Stage | Future chat title | Main files or location | Completion check |
|-------|-------------------|------------------------|------------------|
| 01 | Understand the application | `api/`, `frontend/`, assessment | Dependencies and requirements understood |
| 02 | Prepare tools and accounts | Workstation, AWS, GitHub, Docker Hub | Tools and authentication work |
| 03 | Run containers locally | Compose and Dockerfiles | App, health and local persistence work |
| 04 | Set project configuration | Configuration checklist | All project-specific identifiers agree |
| 05 | Bootstrap Terraform and DNS | `terraform/stacks/01-bootstrap/` | State resources and delegated zone work |
| 06 | Build the Kubernetes cluster | Stack 02, `kops/cluster.yaml` | Cluster and add-on readiness pass |
| 07 | Create AWS application services | `terraform/stacks/03-services/` | Secrets, TLS and IAM handoff exist |
| 08 | Install the Kubernetes platform | Stack 04, ingress and monitoring values | NLB, controllers, storage and DNS ready |
| 09 | Configure the application chart | `helm/agribridge/` | Both environments render correctly |
| 10 | Configure CI and image publication | `.github/workflows/delivery.yaml` | Checks and Docker Hub publication succeed |
| 11 | Deploy and test staging | Staging Helm values | Release and user workflow pass |
| 12 | Promote to production | Production Helm values | Same image release promoted successfully |
| 13 | Verify monitoring and logging | `monitoring/`, app metrics | Targets, logs and alerts verified |
| 14 | Test failure recovery | Operational scripts and release history | Persistence, rollback and restore proven |
| 15 | Handover and reuse | Guides, evidence and state inventory | Rebuild instructions match reality |

## 01 — Understand the application

Read [the assessment](ASSESSMENT.md), [project plan](PROJECT-PLAN.md), the API
configuration and routes, and the frontend's API calls. Identify PostgreSQL as the
durable data store, Redis as an optional cache, and the frontend's same-origin
`/api` proxy. Distinguish liveness `/healthz`, readiness `/readyz`, metrics
`/metrics` and release identity `/version`.

**Provide:** business flows, environment names, availability expectations and data
retention requirements. For a new app, establish its ports, health checks, migration
command, persistent data and secret keys before copying this infrastructure.

**Check:** explain a login/order request from browser to database and identify
which components may be restarted safely.

**New-chat prompt:** “Stage 01: explain this application's components, request
flow, persistent data, health checks and deployment requirements. Map the
assessment to the repository and identify decisions I must make.”

## 02 — Prepare tools and accounts

Follow configuration sections 1–2. Install the pinned baseline tools and authenticate
AWS and GitHub outside Git. Confirm the AWS account/region and the GitHub HTTPS
origin before creating anything. Confirm access to the parent DNS zone and Docker
Hub repositories. No application database password is needed for cloud setup.

```sh
git remote -v
gh auth status
aws sts get-caller-identity
make help
```

**Provide:** operator AWS profile, repository, domain ownership and Docker Hub
username/token. The token goes directly into GitHub Actions secrets in stage 10.

**Check:** every tool version/authentication command in CONFIGURATION.md succeeds;
the account and repository are the intended targets.

**New-chat prompt:** “Stage 02: check my tools, target AWS account, GitHub remote,
Docker Hub access and DNS ownership. Tell me exactly what is missing without
printing credentials.”

## 03 — Build and run containers locally

Review `api/Dockerfile`, `frontend/Dockerfile`, `frontend/nginx.conf.template` and
`docker-compose.yml`. Create the ignored local environment file with disposable
values; follow its comments for the local demonstration accounts.

```sh
cp .env.example .env
# Edit .env with disposable local values before starting.
make local
curl --fail http://localhost:8080/
docker compose exec -T api node -e "fetch('http://localhost:3000/readyz').then(r=>{if(!r.ok)process.exit(1)})"
bash scripts/local-resilience.sh
make stop
```

**Provide:** local-only signing/database/demo values. CI uses its own disposable
Compose values, while cloud secrets are generated separately.

**Check:** login and an order work locally; Redis failure is tolerated and a
PostgreSQL restart preserves data. `make stop` keeps the database volume. Avoid
`docker compose down -v` when data should survive.

**New-chat prompt:** “Stage 03: explain and verify the Dockerfiles and Compose
stack, run the app locally, and demonstrate health, cache failure and database
persistence. Record what passed.”

## 04 — Set the project identity and configuration

Complete configuration sections 3–5 and 8–9. Align domain, cluster name, region,
zones, unique buckets, image repositories, release name, namespaces, SSM paths and
workflow URLs. The Terraform guide explains `stacks/`, `modules/` and `generated/`.
Keep `kops/` flat. Edit authored source, then regenerate cluster Terraform.

```sh
rg -n 'agribridge|deuces\.dev|kops-state-607|macroni607|us-east-1' \
  terraform/stacks terraform/modules kops scripts helm monitoring .github
make check
```

**Provide:** the complete identity table and capacity/retention decisions. Keep
the current values when continuing AgriBridge. Another app needs fresh state and
unique bucket names; copying the current project's state is not a new deployment.

**Check:** no mixed project identities remain. The scripts' literal names match
the stack inputs and chart/workflow values.

**New-chat prompt:** “Stage 04: configure this repository for PROJECT, AWS REGION,
DOMAIN and DOCKER HUB USERNAME. Walk through CONFIGURATION.md, identify every
literal to change, and preserve the module-based folder layout.”

## 05 — Bootstrap Terraform state and delegate DNS

Stack 01 creates/adopts the public project hosted zone and creates protected state,
kOps and OIDC discovery buckets. Supply its non-secret inputs as shown in the
configuration checklist. In the existing project the provisioning script handles
adoption; do not run a fresh unmanaged bootstrap over resources already in use.

For a genuinely fresh project with no pre-existing resources:

```sh
terraform -chdir=terraform/stacks/01-bootstrap init
terraform -chdir=terraform/stacks/01-bootstrap plan
terraform -chdir=terraform/stacks/01-bootstrap apply
terraform -chdir=terraform/stacks/01-bootstrap output -json name_servers
```

Delegate the project subdomain to these name servers at the parent DNS provider.
For AgriBridge this means `agribridge.deuces.dev`, preserving unrelated records
under `deuces.dev`. Check public delegation, for example:

```sh
dig NS agribridge.deuces.dev
```

**Provide:** unique bucket identity and parent-zone delegation. Protect local
bootstrap state; `make provision` later uploads its recovery copy to S3.

**Check:** delegation resolves publicly and bootstrap outputs match the account.
The remaining stacks use the existing S3 keys documented in terraform/README.md.

**New-chat prompt:** “Stage 05: review bootstrap resources/state, create or adopt
the project zone and state buckets safely, and guide DNS delegation. Show the
exact parent DNS record needed and verify public resolution before continuing.”

## 06 — Generate and provision the Kubernetes cluster

Review `kops/cluster.yaml`: Kubernetes/image versions, zones, instance groups,
networking, API access, EBS CSI, AWS controllers and pod identity. The baseline has
one control plane and two workers; choose stronger availability if required.

After stage 05 delegation works, run the orchestrator once:

```sh
make provision
```

It runs bootstrap, generates `terraform/generated/kops/`, prepares the generated
module, patches the admission bootstrap configuration, applies stack 02, exports
an expiring operator kubeconfig, waits for cluster/controllers, then continues
through stages 07–08. It also configures GitHub deployment variables/environments.
Inspect the script before running it: its Terraform applies use `-auto-approve`.

For inspection after cluster creation:

```sh
export KOPS_STATE_STORE=s3://kops-state-607
export KUBECONFIG="$PWD/.runtime/kubeconfig"
kops validate cluster k8s.agribridge.deuces.dev --wait 15m
kubectl get nodes
kubectl -n kube-system get deployments
```

**Provide:** cluster settings and operator/runner API reachability. Never commit
the operator kubeconfig. Do not separately run `kops update --yes`; Terraform
owns the generated AWS resources.

**Check:** three nodes and required controller endpoints are ready. If provisioning
stops here, diagnose events/readiness before resuming; do not skip the gate.

**New-chat prompt:** “Stage 06: inspect the kOps manifest and generated-module
workflow, provision the cluster using Terraform, and verify node, storage,
identity and load-balancer-controller readiness. Explain any failed gate.”

## 07 — Create AWS application services and access

Stack 03 calls the registry, runtime-secrets, TLS, backup, observability,
GitHub-delivery and deployment-config modules. It generates separate runtime
secrets for each environment, IAM roles, ACM validation and SSM deployment handoff.
See CONFIGURATION.md for every supplied/generated input and identity audience.

This stage runs inside `make provision`. Inspect its non-secret outputs afterward:

```sh
terraform -chdir=terraform/stacks/03-services output -raw pipeline_role
terraform -chdir=terraform/stacks/03-services output -raw registry_namespace
```

**Provide:** repository OIDC identity (discovered by the script), Docker Hub
namespace, cluster discovery bucket, environment list and DNS configuration.
Let Terraform generate passwords; never paste secret JSON into a chat or guide.

**Check:** certificate issued, runtime secrets present, IAM audiences/trust scoped
correctly, and deployment SSM parameters exist for each environment.

**New-chat prompt:** “Stage 07: explain and verify the AWS service modules,
generated secrets, ACM certificate, backup/logging resources and GitHub OIDC
deployment role. Check the SSM handoff without exposing secret values.”

## 08 — Install storage, secrets, ingress and monitoring

Stack 04 installs namespaces, storage, External Secrets, NGINX and monitoring, then
records the NLB hostname in DNS. Edit the flat NGINX template under `kops/` and
monitoring values under `monitoring/`. Use the maintained F5 NGINX OSS chart pinned
in Terraform. AWS's controller provisions the NLB for the NGINX Service; a separate
manually created AWS load balancer is unnecessary.

This stage also runs inside `make provision`. If the cluster exists and the script
stopped during services/platform, use:

```sh
make resume
export KUBECONFIG="$PWD/.runtime/kubeconfig"
kubectl -n external-secrets get deployments
kubectl -n ingress get service nginx-ingress-controller
kubectl -n monitoring get pods
kubectl get storageclass agribridge-gp3
```

**Provide:** ingress capacity, ACM ARN through the generated platform map, storage
and monitoring settings. Do not hand-edit the private runtime handoff file.

**Check:** controllers ready, NLB provisioned, public HTTPS 443 configured to
NGINX HTTP 80, app DNS resolves, monitoring pods running. External Secrets uses
upgrade/install recovery for a retained failed release; do not delete its CRDs.

**New-chat prompt:** “Stage 08: verify Terraform's platform installation, F5 NGINX,
AWS NLB, HTTPS/DNS, External Secrets, gp3 storage and monitoring. Resume a partial
apply through the provided script and diagnose failed readiness checks.”

## 09 — Configure and validate the application Helm chart

Read shared `helm/agribridge/values.yaml` and each environment override. Set app
resources, replicas, PostgreSQL storage, Redis behavior, probes, metrics, backup
schedule and staging-only demo seeding. The deployment script supplies image tags,
hostnames and AWS identifiers from SSM; no secret values go into values files.

```sh
helm lint helm/agribridge --set secretArn=validation
bash scripts/render-manifests.sh staging IMAGE_TAG
bash scripts/render-manifests.sh production IMAGE_TAG
```

Rendering requires authenticated AWS access to the SSM deployment handoff. Its
ignored output in flat `kops/` is for inspection; Helm remains the release owner.

**Provide:** all runtime decisions in configuration section 8, including a
production user-onboarding plan. Production deliberately has no demo users.

**Check:** both renders have the correct namespace/hostname, probes, PVCs,
ExternalSecret references and image identity, with no secret plaintext.

**New-chat prompt:** “Stage 09: explain and validate the Helm chart and shared
versus environment values. Check secret references, migrations, seeding, probes,
persistence, ingress, metrics and backups for staging and production.”

## 10 — Configure CI and Docker Hub publication

Review `.github/workflows/delivery.yaml`. Add the existing valid Docker Hub token
as `DOCKERHUB_TOKEN` directly in GitHub Actions repository secrets. Provisioning
sets `DOCKERHUB_USERNAME` and `AWS_DEPLOY_ROLE` variables and creates the two GitHub
environments. Confirm public API/web repositories exist and pulls work without
credentials. No long-lived AWS key is needed in GitHub.

The workflow checks lint, dependency audits, unit/integration coverage, frontend
build, Helm, ingress rendering, scripts and all Terraform roots. Pull requests
run checks. Main pushes/manual dispatch additionally build and exercise the exact
Compose images, push to Docker Hub, then deploy staging and production in sequence.

```sh
gh workflow list
# After the reviewed changes exist on the intended branch:
gh workflow run delivery.yaml --ref YOUR_BRANCH
gh run list --workflow delivery.yaml --limit 5
```

**Provide:** Docker Hub push token. If desired, configure GitHub production
environment reviewers before dispatch; the baseline promotes automatically after
staging succeeds. A manual dispatch starts the entire delivery workflow.

**Check:** checks and publish jobs succeed; the API/web tags identify the same
commit/run. Keep the workflow URL and image digests as evidence.

**New-chat prompt:** “Stage 10: verify the pipeline gates, Docker Hub credential
configuration and GitHub-to-AWS OIDC access. Run the reviewed workflow, inspect
failures, and record the published tag and image digests.”

## 11 — Deploy and test staging

The pipeline calls `bash scripts/deploy.sh staging IMAGE_TAG`. It reads SSM,
fetches a namespace-scoped deployment kubeconfig, generates non-secret Helm values,
performs an atomic upgrade, verifies `/version` and checks public HTTPS.

```sh
helm -n agribridge-staging status agribridge
kubectl -n agribridge-staging get pods,pvc,ingress,externalsecret
curl --fail https://staging.agribridge.deuces.dev/
```

**Provide:** the published immutable release tag. Retrieve the generated staging
demo password privately using the operations guide; never write it into this guide.

**Check:** ExternalSecret ready, PostgreSQL PVC bound, pods healthy, `/version`
matches the requested tag, and login plus create/order/update flows work. A public
sign-in page alone does not prove authenticated business flows.

**New-chat prompt:** “Stage 11: verify the staging release, runtime secrets,
database and image identity, then test the authenticated business workflow.
Capture results without recording passwords.”

## 12 — Promote the same release to production

The production job waits for staging and uses its exact published image tag.
Review `values-production.yaml`, capacity and account-onboarding requirements.
Inspect release history and public TLS after promotion.

```sh
helm -n agribridge-production status agribridge
helm -n agribridge-production history agribridge
kubectl -n agribridge-production get pods,pvc,ingress,externalsecret
curl --fail https://production.agribridge.deuces.dev/
```

**Provide:** a tested release and a production account-onboarding decision. Do not
enable demonstration seeding merely to obtain a production login.

**Check:** staging and production image tags/digests agree, no demo seed runs in
production, and the intended production user can complete an agreed smoke test.

**New-chat prompt:** “Stage 12: promote the staging-tested release to production,
verify the same image identity and healthy rollout, and check production account
onboarding and smoke tests without enabling demo data.”

## 13 — Verify monitoring, dashboards and logs

Use the exact access commands in [OPERATIONS.md](OPERATIONS.md). In separate
terminals, forward private services to your workstation:

```sh
kubectl -n monitoring port-forward svc/monitoring-grafana 3001:80
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-alertmanager 9093:9093
```

Open Grafana at `http://localhost:3001`, Prometheus at `http://localhost:9090` and
Alertmanager at `http://localhost:9093`. Grafana uses `admin` and its generated
Kubernetes secret; see operations for private retrieval. These addresses work only
while your local forwards are running.

**Provide:** retention/storage settings, dashboard needs and a real alert
destination if notifications are required. No external recipient is preconfigured.

**Check:** application ServiceMonitor targets are up, requests change metrics,
alerts evaluate, CloudWatch receives both environment logs, and any configured
notification reaches the chosen destination. Do not infer scraping from running pods.

**New-chat prompt:** “Stage 13: open monitoring securely, verify Prometheus
application targets and metrics, inspect Grafana and CloudWatch logs, and test
alert evaluation/delivery. Record evidence and any missing alert configuration.”

## 14 — Prove resilience, rollback and backup recovery

Follow operations for controlled tests. Start locally with
`bash scripts/local-resilience.sh`, then test staging separately: cache absence,
database pod restart with retained data, and API readiness during recovery.
Record a known-good Helm revision before testing a rollback.

```sh
helm -n agribridge-staging history agribridge
# Substitute a verified prior revision; this changes the staging release.
helm -n agribridge-staging rollback agribridge KNOWN_GOOD_REVISION --wait --timeout 15m
```

Trigger a staging backup using the CronJob procedure in operations, wait for the
Job to complete, and identify its actual S3 object key. Then run:

```sh
bash scripts/restore-drill.sh staging staging/ACTUAL_BACKUP_OBJECT.dump
```

**Provide:** recovery objectives, known-good revision and a real backup key.
The restore drill uses temporary isolated PostgreSQL storage and deletes its pod
after verification; it does not restore into the live application database.

**Check:** Redis loss is tolerated, database data survives restart, rollback
restores the expected version, backup succeeds and an isolated restore verifies
the application tables. Record recovery duration and compare it with objectives.

**New-chat prompt:** “Stage 14: run controlled staging resilience, rollback and
backup/isolated-restore tests. Establish the expected data/version first, restore
normal operation afterward, and record measured results and recovery limits.”

## 15 — Handover, clean up and reuse

Update verification evidence with workflow/commit/tag/digests, URLs, Terraform
state locations, resource ownership and the tests actually passed. Run a no-drift
plan from each initialized stack using the same inputs/backend; resolve unexpected
changes before handover. An expired operator kubeconfig needs refreshing first.

For another project, repeat from stage 01 and configuration section 3. Copy source
and guides, choose a new identity, regenerate kOps output and initialize new state.
Do not copy credentials, runtime files or Terraform state. Keep dependencies and
versions under review rather than assuming this baseline remains current forever.

If retiring an environment, inventory retained volumes, backups, secrets and DNS
before teardown. Remove application releases and Kubernetes LoadBalancer services
while the controllers/cluster still run, then review destruction in reverse stack
order (04 → 03 → 02 → 01). Account for retained PVCs/volumes and protected buckets;
preserve required data and state recovery copies. There is intentionally no
one-command destructive cleanup target.

**Provide:** ownership, retention/cost decisions, recovery evidence and next-project
identity. Document any deviations from this blueprint.

**Check:** a new operator can follow the guides with only the listed inputs and
can distinguish completed acceptance checks from pending work.

**New-chat prompt:** “Stage 15: review the repository and verification evidence
for handover, check for Terraform drift, and prepare a configuration/change list
for reusing this blueprint in my next project. Explain retained resources and
costs before proposing any cleanup.”
