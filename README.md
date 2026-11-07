# AgriBridge

## Deployment status — 2 November 2026

The rebuilt AWS services and three-node kOps cluster are running. External Secrets,
NGINX ingress, monitoring and logging passed their platform checks; Terraform's
cluster, services and platform consistency checks reported no changes.
Argo CD and its bootstrap release are installed; all five reported Argo pods
are ready, and the refreshed platform plan reports no changes. Reviewed source
publication and the first application CI/CD run remain pending. Stage 6 source
passed local acceptance. See the
[session record](docs/REBUILD-SESSION.md) and [GitOps runbook](argocd/README.md).
The URLs below have DNS/TLS infrastructure but await the first application release.

A grain marketplace connecting smallholder farmers and institutional buyers.
React/Vite frontend, Express API, PostgreSQL and Redis; deployed to a kOps cluster
on AWS with Terraform, Helm and GitHub Actions.

- [Staging application](https://staging.agribridge.deuces.dev)
- [Production application](https://production.agribridge.deuces.dev)
- [Rebuild this project, one step/chat at a time](docs/REBUILD-GUIDE.md)
- [All inputs and configuration to supply](docs/CONFIGURATION.md)
- [Current staged rebuild and approval checklist](docs/REBUILD-SESSION.md)

## Where things belong

| Folder/file | Purpose |
|-------------|---------|
| `frontend/` | Browser application, tests, Dockerfile and Nginx routing |
| `api/` | API application, migrations, tests and Dockerfile |
| `terraform/` | AWS application services; `bootstrap/`, `cluster/` and `platform/` run the dependent setup steps |
| `terraform/modules/` | Reusable Terraform service definitions |
| `terraform/generated/kops/` | Generated cluster code; regenerate rather than hand-edit |
| `kubedefs/` | Flat cluster YAML, ingress values and optional rendered manifests |
| `argocd/` | Argo CD project, applications, controller values and CI-managed environment image selections |
| `helm/agribridge/` | One application chart, with staging and production values |
| `monitoring/` | Prometheus/Grafana and Fluent Bit configuration |
| `.github/workflows/` | Checks, Docker Hub publication and deployment |
| `scripts/` | Infrastructure, deployment and operations automation |
| `docs/` | Configuration, rebuild sequence, operations and evidence |
| `docker-compose.yml` | Complete local application stack |
| `Makefile` | Short commands for common tasks |

Infrastructure runs in this order: **bootstrap → cluster → AWS services →
Kubernetes platform**. Each step keeps its existing state; generated cluster files stay
separate. [Terraform's starting guide](terraform/README.md) explains each part.

## Common commands

```sh
make help
cp .env.example .env   # Local-only throwaway values; see configuration guide
make local
```

For an isolated verification run, use `make local-verify`. It builds throwaway
images, exercises login and PostgreSQL integration tests, checks cache failure
and database-volume persistence, then removes only its own test containers and
volumes. It uses local ports 18080 and 15433 by default; override them with
`VERIFY_WEB_PORT` and `VERIFY_PG_PORT` if needed. Docker engine access is required.

Local application: http://localhost:8080. Stop it with `make stop`; local database
data is retained. For AWS, authenticate AWS and GitHub, complete the configuration
checklist, then follow the reviewed planning/apply sequence in the session record.
During this staged rebuild, use the separate planning commands and GitOps runbook.

## Release path

The prepared workflow checks the code, builds and exercises the images, scans
them and publishes to Docker Hub. It records published digests in Git for Argo CD
to deploy with the application chart. After staging passes public HTTPS,
readiness and build-identity checks, production receives the same digests without
rebuilding. A configured GitHub production-environment reviewer gate pauses that
promotion; otherwise it follows staging automatically. This path still requires
its first successful live run. Runtime secrets come from AWS Secrets Manager
through External Secrets.

Route 53 points to one AWS Network Load Balancer. ACM terminates HTTPS, and
maintained F5 NGINX OSS routes requests into the application. Prometheus/Grafana
collect metrics; Fluent Bit sends application logs to CloudWatch.

## Guides

| You want to… | Read |
|--------------|------|
| Rebuild or follow this in future chats | [Rebuild guide](docs/REBUILD-GUIDE.md) |
| Know what values to enter and where | [Configuration checklist](docs/CONFIGURATION.md) |
| Understand or change Terraform | [Terraform guide](terraform/README.md) |
| Deploy, inspect dashboards, roll back or restore | [Operations](docs/OPERATIONS.md) |
| See what has actually been verified | [Verification](docs/VERIFICATION.md) |
| Read the original project requirements | [Assessment](docs/ASSESSMENT.md) |

Staging includes demo accounts; production is deliberately unseeded. Retrieve the
staging demo password from Secrets Manager as described in the operations guide.
No passwords, access tokens, state files or kubeconfigs belong in Git.
