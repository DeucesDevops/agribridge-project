# Pipeline

The workflow is [`.github/workflows/cicd.yaml`](../.github/workflows/cicd.yaml).
Jobs run in this order. A failure stops everything after it.

| Job | What it does |
|---|---|
| Lint and test | ESLint, unit tests, coverage, API tests against PostgreSQL, and the JUnit report |
| Gitleaks | Scans the Git history for secrets |
| SonarQube | Quality gate on `main`, only when the token and URL are set. Otherwise the job succeeds and says it was skipped |
| Trivy filesystem scan | Fails on high or critical findings in `api/` and `frontend/` |
| Checkov and configuration | `terraform fmt`, then `terraform validate` for production, dev, and bootstrap, `helm lint`, then Checkov on Terraform, the rendered chart and both Dockerfiles |
| Build, scan, SBOM and push | Builds both images, scans them with Trivy, writes CycloneDX SBOMs, and pushes to Docker Hub on `main` |
| Publish production image tags | Waits for the `production` environment, then commits the image tag on `main` |

Pull requests and pushes to `dev` run through the image scan. They do not push
images or change the production tag. A push to `main` pushes the images, then
waits for the production environment before it writes the tag. Argo CD syncs
the commit. The job does not call AWS or Helm.

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
| Variable | `AWS_ROLE_ARN` | No | Terraform writes this. The pipeline does not assume it. Use it when you export a kubeconfig |
| Variable | `AWS_REGION` | No | Terraform writes `us-east-1` |
| Variable | `KOPS_STATE_STORE` | No | Terraform writes `s3://kops-state-607` |
| Variable | `KOPS_CLUSTER_NAME` | No | Terraform writes `k8s.agribridge.deuces.dev` |
| Variable | `ZONE_NAME` | No | Terraform writes the zone |
| Variable | `ACM_CERTIFICATE_ARN` | No | Terraform writes this and passes it to the Argo CD Application |
| Variable | `BACKUP_BUCKET` | No | Terraform writes this and passes it to the Argo CD Application |
| Variable | `BACKUP_ROLE_PRODUCTION` | No | Terraform writes this and passes it to the Argo CD Application |
| Variable | `PRODUCTION_URL` | No | Terraform writes `https://production.agribridge.deuces.dev`. The production environment link uses it |
| Variable | `GRAFANA_URL` | No | Terraform writes `https://grafana.agribridge.deuces.dev` |
| Variable | `ARGOCD_URL` | No | Terraform writes `https://argocd.agribridge.deuces.dev` |
| Variable | `SONAR_HOST_URL` | No | HTTPS URL of SonarQube. The job skips when this is empty |
| Secret | `SONAR_TOKEN` | No | SonarQube project token. The job skips when this is empty |

Image push uses the Docker Hub token and does not need AWS. The tag commit
uses the workflow's `GITHUB_TOKEN` with `contents: write`. It does not need a
personal access token while `main` accepts that push. If a ruleset later
blocks Actions from pushing to `main`, allow this workflow through that
ruleset. The default image repositories
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
| `production` | Required reviewer | The commit that sets the production image tag. Argo CD syncs only after that commit is on `main` |

GitHub creates an environment automatically the first time a job uses it, and
that automatic environment has no reviewers. Let Terraform create `production`
and add the reviewer before the first image push, or the first tag commit will
not wait.

The tag job checks out `main`, writes `api.tag` and `web.tag` in
`helm/agribridge/values-production.yaml`, and pushes. The author and committer
are `DeucesDevops <macroni607@gmail.com>`. The message is
`deploy: set production images to <sha> [skip ci]`. GitHub skips workflows
when the head commit contains `[skip ci]`, so the bump does not build the
images a second time. If `main` already records a newer commit, the job leaves
that tag in place.

The GitHub Actions role can still read the kOps state bucket.
`kops export kubeconfig --admin` uses that to write a kubeconfig. The admin
key is in the state bucket, so treat the role as cluster-admin access. The
image-tag job does not assume the role.
