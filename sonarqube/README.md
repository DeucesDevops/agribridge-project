# SonarQube code quality

SonarQube adds source-code analysis, duplication and maintainability findings,
security rules and coverage reporting to AgriBridge. It complements ESLint,
Vitest, `npm audit` and Trivy. The application does not depend on SonarQube at
runtime, and this folder does not provision or contact AWS.

## What is included

| File | Purpose |
|------|---------|
| `compose.yaml` | Local Community Build server, its own PostgreSQL database and an on-demand scanner |
| `.env.example` | Local database password, UI port and analysis-token template |
| `sonar-project.properties` | One `agribridge` project, analysis scope, coverage import and quality-gate enforcement |
| `prepare-coverage.py` | Validates and combines component LCOV reports using repository-relative source paths |
| `test_coverage.py` | Checks path mapping, report combination and missing/invalid coverage failures |
| `../.github/workflows/delivery.yaml` | Optional main-branch gate inside `checks`, before the dependent `publish` job |

The analysis includes API JavaScript, frontend JavaScript/JSX/CSS, authored
Terraform, both application Dockerfiles and the application Compose definition,
as supported by the installed analyzers. Tests are classified separately.
Generated kOps code, Terraform caches/state/plans and dependencies are excluded.
Helm template rendering and Kubernetes correctness remain covered by the existing
CI checks; this is not a replacement for those checks.

## Start locally without AWS

Requirements: Docker Desktop with Compose and several GB of free memory, Node/npm
and Python 3. Allocate at least 4 GB RAM to the SonarQube server plus headroom for
its database and scanner (8 GB or more for Docker Desktop is a practical starting
point). No running application containers or Kubernetes cluster are needed.

From the repository root:

```sh
cp sonarqube/.env.example sonarqube/.env
# Edit sonarqube/.env: set SONAR_DB_PASSWORD to a unique local password.
make sonar-up
```

Open <http://localhost:9000> (or your `SONAR_PORT`). First startup can take several
minutes. Log in with SonarQube's initial `admin` / `admin` account and change the
password when prompted. Create a **local project** with project key `agribridge`
and main branch `main`. Choose the built-in **Sonar way** quality gate and an
appropriate new-code definition, such as a 30-day window. Generate
a project analysis token for `agribridge` under **My Account → Security**, give it
an expiry date and put it in `SONAR_TOKEN` in the ignored `sonarqube/.env` file.

Scan a checkout of `main` so local results represent the same branch as CI:

```sh
make sonar-scan
```

This runs both existing coverage suites, validates every LCOV source path,
combines their reports and starts the scanner. The scanner connects to
`http://sonarqube:9000` on its private Compose network. The browser uses localhost.
The repository is mounted read-only; scanner working files stay in its temporary
container. Results and issue history are stored in SonarQube's persistent volumes.

`sonar.qualitygate.wait=true` makes the command wait up to 300 seconds for the
server's quality-gate result. A failed gate, authentication error, unavailable
server or timeout fails the command. A successful report upload is not enough.
Review findings in the UI; security hotspots may require a human review.

Stop the local server and database while retaining the results:

```sh
make sonar-down
```

These commands operate only on the separate `agribridge-sonarqube` Compose project.
`make stop` still stops the application stack. Do not add `--volumes` to the
SonarQube shutdown command unless you intend to erase its database and history.

## Enable GitHub Actions later

The delivery integration is **disabled unless `SONAR_ENABLED` is exactly `true`**.
A disabled integration is reported in the workflow summary; it is not evidence
of a passing SonarQube scan. Repository settings have not been changed by adding
these files.

The existing jobs run on GitHub-hosted runners. They cannot reach SonarQube on your
Mac through `localhost:9000`; localhost there means the runner itself. Use a
server reachable by that runner over HTTPS, or adapt the analysis to a trusted
self-hosted runner with network access. You can continue using local scans
without enabling CI or creating any cloud infrastructure. Do not expose the local
development server directly to the internet for this purpose.

In **GitHub repository → Settings → Secrets and variables → Actions**, configure:

| Type | Name | Value |
|------|------|-------|
| Variable | `SONAR_HOST_URL` | HTTPS URL reachable from the GitHub-hosted runner |
| Secret | `SONAR_TOKEN` | Project analysis token for `agribridge` on that server |
| Variable | `SONAR_ENABLED` | `true` to enforce the gate in the delivery workflow; leave unset while offline |

Create the same `agribridge` project and choose its quality gate on that server
first. Tokens belong to the server that issued them. For a custom certificate
authority, configure `SONAR_ROOT_CERT` on the scan-action steps as described in
the official action documentation; do not disable TLS verification.

To verify CI scanning while AWS remains offline, dispatch **Actions → Verify,
publish and release through GitOps → Run workflow**, choosing `main` and enabling
`analysis_only`. This requires the URL and token even if `SONAR_ENABLED` is unset.
It runs the checks and SonarQube gate, then skips image publication and all
release jobs. The previous separate analysis workflow has been consolidated into
this mode of `delivery.yaml`.

When enabled, the delivery sequence is:

1. Lint, dependency audit, application tests and coverage.
2. SonarQube analysis and quality gate in `checks`.
3. Remaining platform validation; all `checks` must succeed.
4. Docker build, runtime checks, Trivy scan and image publication in `publish`.
5. Existing Argo CD staging verification and production promotion.

The gate has no `continue-on-error` override. Missing settings or a failed scan
fail `checks`, preventing the dependent image-publication job. Community Build
supports main-branch analysis only, so pull requests keep the existing CI checks
and do not receive a SonarQube scan. Feature-branch and pull-request analysis
require a supported edition/service and a corresponding workflow change.

## Coverage and quality-gate expectations

The API's current Vitest coverage includes `api/src/domain/**/*.js`; the frontend
currently tests its formatting helpers. Their high percentages apply to those
measured files. SonarQube also analyses the remaining application code, so its
overall coverage can be much lower. No application files are excluded from
SonarQube coverage to inflate that figure. SonarQube imports coverage; it does not
execute tests or manufacture missing coverage.

The selected server-side quality gate defines the actual conditions. Keep **Sonar
way** as the starting point, review its conditions and new-code definition in the
UI, and add tests or fix findings before claiming the project passes. No scan
result or passing SonarQube gate is claimed by these configuration files.

## Troubleshooting and maintenance

- If startup fails, inspect `docker compose --env-file sonarqube/.env -f
  sonarqube/compose.yaml logs --tail=100 sonarqube`. Check memory, disk space and
  Elasticsearch host requirements. On Linux the Docker host needs
  `vm.max_map_count >= 524288` and `fs.file-max >= 131072`; Compose sets the
  process limits but cannot configure these host kernel settings. On macOS these
  settings apply inside Docker Desktop's Linux VM. Follow Sonar's host guidance;
  do not disable Elasticsearch bootstrap checks.
- If a token is rejected, check its expiry, server and project permissions.
- If coverage preparation fails, run both `test:coverage` scripts again from the
  current checkout. The helper fails on missing/empty reports and unresolved paths
  instead of silently importing zero coverage.
- If the UI port is occupied, change `SONAR_PORT` in `sonarqube/.env` and recreate
  the server with `make sonar-up`; the scanner's internal URL stays the same.
- Images and the scanner action are version-pinned for reproducibility. Review
  supported releases before use, update the server image when appropriate, and
  back up its PostgreSQL database before upgrades. Local volumes are not backups.

## Official references

- [Docker installation](https://docs.sonarsource.com/sonarqube-community-build/server-installation/from-docker-image/set-up-and-start-container)
- [GitHub Actions and main-branch limitations](https://docs.sonarsource.com/sonarqube-community-build/devops-platform-integration/github-integration/adding-analysis-to-github-actions-workflow)
- [JavaScript LCOV coverage](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/test-coverage/javascript-typescript-test-coverage)
- [Official scan action](https://github.com/SonarSource/sonarqube-scan-action)
