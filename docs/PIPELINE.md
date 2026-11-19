# Pipeline

The workflow is [`.github/workflows/cicd.yaml`](../.github/workflows/cicd.yaml).
Jobs run in this order. A failure stops everything after it.

| Job | What it does |
|---|---|
| Lint and test | ESLint, unit tests, coverage, API tests against PostgreSQL, and the JUnit report |
| Gitleaks | Scans the Git history for secrets |
| SonarQube | Quality gate on `main`, only when the token and URL are set. Otherwise the job succeeds and says it was skipped |
| Trivy filesystem scan | Fails on high or critical findings in `api/` and `frontend/` |
| Checkov and configuration | `terraform fmt`, `terraform validate`, `helm lint`, then Checkov on Terraform, the rendered chart and both Dockerfiles |
| Build, scan, SBOM and push | Builds both images, scans them with Trivy, writes CycloneDX SBOMs, and pushes to Docker Hub on `main` |
| Deploy QA | `helm upgrade` into `agribridge-qa` |
| Deploy production | Waits for the `production` environment, then installs the same tag into `agribridge-production` |

Pull requests and pushes to `dev` run through the image scan. They do not push
or deploy. A push to `main` pushes and deploys only after `AWS_ROLE_ARN` is set.

Checkov runs a short starter list in [`.github/checkov.yaml`](../.github/checkov.yaml).
It scans the Terraform in this repository.

## GitHub settings

Create these under **Settings → Secrets and variables → Actions**.

| Kind | Name | Required | Value |
|---|---|---|---|
| Secret | `DOCKERHUB_USERNAME` | To push | Docker Hub user that owns the image repositories |
| Secret | `DOCKERHUB_TOKEN` | To push | Docker Hub access token with write access to those repositories |
| Variable | `API_IMAGE_REPOSITORY` | No | `docker.io/macroni607/agribridge-api` when unset |
| Variable | `WEB_IMAGE_REPOSITORY` | No | `docker.io/macroni607/agribridge-web` when unset |
| Variable | `AWS_ROLE_ARN` | To deploy | Terraform writes this |
| Variable | `AWS_REGION` | No | Terraform writes `us-east-1`. The workflow uses that when the variable is missing |
| Variable | `CLUSTER_NAME` | No | Terraform writes `agribridge` |
| Variable | `ZONE_NAME` | No | Terraform writes the zone. CI builds the hostnames from it |
| Variable | `ACM_CERTIFICATE_ARN` | For deploy | Terraform writes this |
| Variable | `BACKUP_BUCKET` | For production | Terraform writes this |
| Variable | `BACKUP_ROLE_PRODUCTION` | For production | Terraform writes this |
| Variable | `BACKUP_ROLE_QA` | No | Terraform writes this. QA backup stays off unless the values file enables it |
| Variable | `QA_URL` | No | Terraform writes `https://qa.<zone>` |
| Variable | `PRODUCTION_URL` | No | Terraform writes `https://production.<zone>` |
| Variable | `GRAFANA_URL` | No | Terraform writes `https://grafana.<zone>` |
| Variable | `SONAR_HOST_URL` | No | HTTPS URL of SonarQube. The job skips when this is empty |
| Secret | `SONAR_TOKEN` | No | SonarQube project token. The job skips when this is empty |

Actions assumes `AWS_ROLE_ARN` with GitHub's OIDC token when it deploys. Image
push uses the Docker Hub token and does not need AWS. The default repositories
are the ones this project published before: `docker.io/macroni607/agribridge-api`
and `docker.io/macroni607/agribridge-web`. Set the two repository variables
when the Docker Hub user is different. The repositories need to be public so
the nodes can pull them without an image pull secret.

The lint job uploads `api/reports/junit-unit.xml`,
`api/reports/junit-integration.xml` and `frontend/reports/junit.xml` as the
`junit` artifact, writes a summary of failures on the job, and publishes the
same files to the Actions test report. A failed test still fails the job.
The report step does not decide that.

## Environments

Create two environments under **Settings → Environments**.

| Environment | Reviewers | What it protects |
|---|---|---|
| `qa` | None | The QA Helm install. It should start as soon as the images are pushed |
| `production` | Required reviewer | The production Helm install. Add yourself before the first production deploy |

GitHub creates an environment automatically the first time a job uses it, and
that automatic environment has no reviewers. Create `production` and add a
required reviewer first, or the first promotion will not wait.

The deploy role can call `eks:DescribeCluster`. An access entry makes it a
cluster admin, which is what `helm upgrade` needs. Treat that role as
cluster-admin access.
