# AgriBridge

A grain marketplace connecting smallholder farmers and institutional buyers.
React/Vite frontend, Express API, PostgreSQL and Redis; deployed to a kOps cluster
on AWS with Terraform, Helm and GitHub Actions.

- [Staging application](https://staging.agribridge.deuces.dev)
- [Production application](https://production.agribridge.deuces.dev)
- [Rebuild this project, one step/chat at a time](docs/REBUILD-GUIDE.md)
- [All inputs and configuration to supply](docs/CONFIGURATION.md)

## Where things belong

| Folder/file | Purpose |
|-------------|---------|
| `frontend/` | Browser application, tests, Dockerfile and Nginx routing |
| `api/` | API application, migrations, tests and Dockerfile |
| `terraform/stacks/` | **Run Terraform here**: numbered stacks 01 through 04 |
| `terraform/modules/` | Reusable Terraform service definitions |
| `terraform/generated/kops/` | Generated cluster code; regenerate rather than hand-edit |
| `kops/` | Flat cluster YAML, NGINX values and optional rendered manifests |
| `helm/agribridge/` | One application chart, with staging and production values |
| `monitoring/` | Prometheus/Grafana and Fluent Bit configuration |
| `.github/workflows/` | Checks, Docker Hub publication and deployment |
| `scripts/` | Infrastructure, deployment and operations automation |
| `docs/` | Configuration, rebuild sequence, operations and evidence |
| `docker-compose.yml` | Complete local application stack |
| `Makefile` | Short commands for common tasks |

Infrastructure runs in this order: **bootstrap → cluster → AWS services →
Kubernetes platform**. Stacks call reusable modules; generated cluster files stay
separate. [Terraform's starting guide](terraform/README.md) explains each part.

## Common commands

```sh
make help
cp .env.example .env   # Local-only throwaway values; see configuration guide
make local
```

Local application: http://localhost:8080. Stop it with `make stop`; local database
data is retained. For AWS, authenticate AWS and GitHub, complete the configuration
checklist, then use `make provision` or `make resume`.

## Release path

GitHub Actions checks the code, builds and exercises the images, pushes them to
`macroni607/agribridge-api` and `macroni607/agribridge-web`, deploys staging, then
promotes the same image tags to production. Runtime secrets come from AWS Secrets
Manager through External Secrets.

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
