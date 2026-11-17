# Architecture

A browser opens `https://qa.<zone>` or `https://production.<zone>`. Route 53
sends that name to one Application Load Balancer. The load balancer is created
by the AWS Load Balancer Controller, which kOps installs, from the Ingress in
the application chart. TLS uses the ACM certificate Terraform requests.

The web pod serves the React files and proxies `/api` to the API Service in the
same namespace. The API reads and writes PostgreSQL and uses Redis as a cache.
If Redis is down, the API keeps serving from PostgreSQL and reports that on
`/readyz`.

Each namespace has its own database volume and its own Secrets Manager secret.
External Secrets copies `PGPASSWORD`, `JWT_SECRET` and `SEED_PASSWORD` into the
namespace. The External Secrets pod assumes an IAM role. The trust policy uses
the OIDC issuer kOps publishes to the discovery bucket, with audience
`amazonaws.com`. That is the kOps pod-identity webhook, not an EKS pod-identity
association.

Prometheus scrapes the API `/metrics` endpoint. Promtail ships container logs
to Loki. Tempo is installed so Grafana has a trace datasource. The application
does not emit traces yet.

Images are built by GitHub Actions and stored in ECR. The node role kOps creates
can pull from ECR because `iam.allowContainerRegistry` is set. QA and production
deploys are `helm upgrade` from GitHub Actions. They are not a GitOps reconcile
loop.

| Namespace | Host | Demo data |
|---|---|---|
| `agribridge-qa` | `qa.<zone>` | Loaded on startup |
| `agribridge-production` | `production.<zone>` | Not loaded |
