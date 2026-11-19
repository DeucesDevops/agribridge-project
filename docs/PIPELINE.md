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
| Deploy production | Waits for the `production` environment, then installs that tag into `agribridge-production` |

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
| Variable | `KOPS_STATE_STORE` | No | Terraform writes `s3://kops-state-607` |
| Variable | `KOPS_CLUSTER_NAME` | No | Terraform writes `k8s.agribridge.deuces.dev` |
| Variable | `ZONE_NAME` | No | Terraform writes the zone. CI builds the hostnames from it |
| Variable | `ACM_CERTIFICATE_ARN` | For deploy | Terraform writes this |
| Variable | `BACKUP_BUCKET` | For production | Terraform writes this |
| Variable | `BACKUP_ROLE_PRODUCTION` | For production | Terraform writes this |
| Variable | `PRODUCTION_URL` | No | Terraform writes `https://production.agribridge.deuces.dev` |
| Variable | `GRAFANA_URL` | No | Terraform writes `https://grafana.agribridge.deuces.dev` |
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

Terraform creates one environment, `production`, and adds `github_reviewer`
as a required reviewer.

| Environment | Reviewers | What it protects |
|---|---|---|
| `production` | Required reviewer | The production Helm install. The reviewer has to approve before the job starts |

GitHub creates an environment automatically the first time a job uses it, and
that automatic environment has no reviewers. Let Terraform create `production`
and add the reviewer before the first deploy, or the first deploy will not wait.

The deploy role can read the kOps state bucket. `kops export kubeconfig --admin`
uses that to write a kubeconfig, which is what `helm upgrade` needs. The
admin key is in the state bucket, so treat the role as cluster-admin access.
