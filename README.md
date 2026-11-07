# AgriBridge

A grain marketplace connecting farmers and buyers, used to demonstrate a complete
DevOps delivery process: React/Vite frontend, Express API, PostgreSQL and Redis.

The AWS deployment was shut down on 2 November 2026. Application delivery,
infrastructure and maintenance now have separate GitHub Actions workflows. These
workflow changes have not yet been exercised against AWS; local validation is
recorded in [VERIFICATION.md](docs/VERIFICATION.md). Dated records in
[docs/evidence](docs/evidence/) describe earlier deployments, not current uptime.

## How delivery works

1. Docker Compose runs the same application Dockerfiles locally.
2. GitHub Actions checks both components, tests against real PostgreSQL, enforces
   coverage, builds and exercises the images, scans them and publishes to Docker Hub.
3. Actions commits the published image digests to the staging GitOps values.
4. Argo CD renders one Helm chart and reconciles staging. Actions verifies HTTPS,
   readiness and the running commit before promoting the same digests to production.
5. Terraform creates the AWS infrastructure and installs cluster controllers.
   External Secrets delivers Secrets Manager values at runtime. Prometheus/Grafana
   collect metrics and Fluent Bit sends logs to CloudWatch.

## Repository layout

| Location | Responsibility |
|---|---|
| `frontend/`, `api/` | Application source, tests and Dockerfiles |
| `.github/workflows/delivery.yaml` | Checks, image publication, staging and production releases |
| `.github/workflows/infrastructure.yaml` | Manually requested Terraform plans, approved applies and teardown |
| `.github/workflows/operations.yaml` | Live checks, backups, isolated restore tests and staging resilience |
| `.github/actions/cloud-tools/` | Shared tool setup and AWS OIDC authentication for cloud jobs |
| `terraform/` | AWS services, bootstrap, cluster, platform and reusable modules |
| `kubedefs/` | kOps cluster definition and ingress-controller configuration |
| `helm/agribridge/` | One application chart; component templates and environment values |
| `helm/argocd-bootstrap/` | Terraform's installation of the Argo CD project and Applications |
| `argocd/` | Argo CD configuration and CI-managed runtime references/image selections |
| `monitoring/` | Metrics and log collection configuration |
| `sonarqube/` | Local analysis server and optional CI quality gate |
| `scripts/` | Five focused helpers and their tests; workflows own cloud sequencing |
| `docs/` | Requirements, architecture, setup, operations and dated evidence |

Terraform owns infrastructure and controller installation. Argo CD owns the
application resources produced by Helm. Application YAML is maintained in the
chart; `make render` lets you inspect it without maintaining a second copy.

## Start locally

```sh
cp .env.example .env
make local
```

Open http://localhost:8080. `make stop` retains local database data.
`make local-verify` creates an isolated disposable stack and exercises integration,
cache degradation and database persistence. Docker engine access is required.

For helper checks, create a virtual environment and install
`scripts/requirements.txt`, then run `make check`. `make help` lists local commands.

## Run cloud workflows

Set up the runner, AWS roles, GitHub environments and repository settings described
in [CONFIGURATION.md](docs/CONFIGURATION.md), then follow
[REPRODUCTION.md](docs/REPRODUCTION.md). Infrastructure stages run in this order:
**bootstrap → cluster → services → platform**. Terraform retains the existing state
keys; the folder refactor does not create new state.

Infrastructure and operations workflows run only when explicitly dispatched from
`main`. Application delivery runs on application/configuration changes merged into
`main` and validates pull requests. Infrastructure plans stay in encrypted private
S3 storage; apply uses the exact saved plan after the configured environment approval.

SonarQube stays optional until a reachable server and credentials are configured.
For analysis without publication or deployment, dispatch `delivery.yaml` with
`analysis_only=true`. Local SonarQube requires no AWS resources.

## Guides

- [Original assessment](docs/ASSESSMENT.md)
- [Architecture and interview explanation](docs/ARCHITECTURE.md)
- [Configuration and access prerequisites](docs/CONFIGURATION.md)
- [Reproduction sequence](docs/REPRODUCTION.md)
- [Operations, rollback and teardown](docs/OPERATIONS.md)
- [Validation and limitations](docs/VERIFICATION.md)

Passwords, tokens, state, kubeconfigs and plan bundles never belong in Git.
