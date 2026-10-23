# Plain Kubernetes deployment on kOps

These are application manifests for an existing kOps cluster. Helm is deferred.
Run commands from the repository root. Nothing here creates a cluster, installs
controllers, provisions AWS resources directly, or deploys automatically.
Applying the Ingress does ask the AWS Load Balancer Controller to create an ALB.

The current AWS design uses **RDS PostgreSQL and ElastiCache outside Kubernetes**.
There are therefore no PostgreSQL/Redis StatefulSets, Services or PVCs here.
The local Docker Compose environment stays separate.

## Definition files

| File | Purpose |
| --- | --- |
| `namespace.yaml` | Dedicated `agribridge` namespace. |
| `serviceaccount.yaml` | Application identity without a mounted Kubernetes API token. |
| `api-configmap.yaml` | Non-secret API settings, database endpoint and feature flags. |
| `web-configmap.yaml` | Kubernetes Nginx config; replaces the image's Docker DNS/proxy config. |
| `api-deployment.yaml` | API replicas, image, configuration, resources, probes and graceful termination. |
| `web-deployment.yaml` | Static frontend replicas with mounted Nginx config and writable `/tmp`. |
| `api-service.yaml` | API NodePort Service, forwarding to port 3000. |
| `web-service.yaml` | Web NodePort Service, forwarding port 80 to container port 8080. |
| `poddisruptionbudgets.yaml` | Keep at least one replica per workload during voluntary evictions. |
| `secretstore.yaml` | Namespaced connection to AWS Secrets Manager through ESO. |
| `externalsecret.yaml` | Sync credentials into the `api-secrets` Kubernetes Secret. |
| `migration-job.yaml` | Run the release's SQL migrations once before the API rollout. |
| `ingress.yaml` | HTTPS ALB routing, certificate, HTTP redirect and worker target selection. |
| `hpa.yaml` | CPU-based API/web autoscaling when Metrics Server is available. |

All definition files live directly in `kops/`, with no subfolders. Apply individual
files with `kubectl apply -f kops/FILENAME.yaml` in the stages below.
Use the staged commands so secret synchronization and migrations finish before
rollout, and apply `hpa.yaml` only when Metrics Server is available.

## Prerequisites and values to supply

1. An existing kOps cluster, accessible kubeconfig, and worker capacity for two API
   and two web replicas plus rolling-update surge pods. Host spreading is a soft
   preference; two replicas on one worker do not provide node-failure resilience.
2. AWS Load Balancer Controller with its IAM permissions and an `alb` IngressClass.
   Configure public subnet discovery/tags and ALB-to-worker NodePort security-group
   rules. Workers remain private; never expose NodePorts to the public internet.
3. External Secrets Operator and CRDs serving `external-secrets.io/v1`. Its
   controller must have AWS workload identity configured for this kOps cluster,
   with access limited to the application's secret and any required KMS key.
   `SecretStore` intentionally uses that controller identity, with no static AWS
   access keys. Only trusted operators should be able to edit SecretStores.
4. RDS database `agribridge`, an appropriate database user, worker-to-RDS access on
   5432, and sufficient DB connections: maximum API replicas × pool size, plus
   surge pods, migrations and administration. Set `PGHOST` and adjust DB/user values.
5. Published API/web images compatible with worker CPU architecture, ideally
   pinned as `registry/repository@sha256:...`. Replace all three image references;
   **the migration Job and API Deployment must use the same API digest**.
   Configure worker ECR pull permissions/credential provider for private ECR.
6. A DNS hostname, ACM certificate in the ALB's region, and worker instance-group
   label. Replace `replace-app-hostname.invalid`, `REPLACE_ACM_CERTIFICATE_ARN`,
   and `REPLACE_WORKER_INSTANCE_GROUP`. The supplied selector targets one worker
   group; adapt it to a common worker label if multiple groups should receive
   traffic. Point your chosen hostname to the ALB after it exists.
7. Replace `REPLACE_AWS_REGION` and all secret-name placeholders in `externalsecret.yaml`.
   The referenced Secrets Manager JSON object must contain `PGPASSWORD`,
   `JWT_SECRET` and `REDIS_URL`. Use a strong JWT secret and the real DB password.
   Never put their values in these files. `REDIS_URL` should be an authenticated
   `rediss://...` URL for TLS ElastiCache; percent-encode credentials in the URL.
   While caching is disabled, this property may be an unused non-secret placeholder
   URL such as `redis://unused.invalid:6379`; the key must still exist for ESO sync.

Redis starts **disabled**. The current client awaits reconnects during startup,
which can prevent the HTTP server from starting if Redis is unavailable. Verify
ElastiCache TLS/authentication and port 6379 connectivity before enabling
`REDIS_ENABLED`. `REDIS_REQUIRED=false` does not bound that startup wait.

`PGSSL=true` enables TLS, but the existing API database client sets
`rejectUnauthorized: false`. Add RDS CA trust and certificate verification in the
application before treating this as a production deployment. These manifests are
an initial deployment scaffold; resource sizing also needs load testing.

## Apply in stages

Replace the values above first. `api-migrate-replace-release-id` must become a
unique lowercase DNS-compatible name for each release, for example
`api-migrate-a1b2c3d4`. Job pod templates cannot be updated in place.
Do not change an existing completed Job and expect migrations to run again.

```sh
# 1. Confirm the intended cluster before any writes.
kubectl config current-context

# 2. Namespace, identity, configuration, Services and disruption budgets.
kubectl apply -f kops/namespace.yaml
kubectl apply -f kops/serviceaccount.yaml
kubectl apply -f kops/api-configmap.yaml
kubectl apply -f kops/web-configmap.yaml
kubectl apply -f kops/api-service.yaml
kubectl apply -f kops/web-service.yaml
kubectl apply -f kops/poddisruptionbudgets.yaml

# 3. Fetch secrets; do not proceed if either wait fails.
kubectl apply -f kops/secretstore.yaml
kubectl -n agribridge wait --for=condition=Ready secretstore/aws-secretsmanager --timeout=120s
kubectl apply -f kops/externalsecret.yaml
kubectl -n agribridge wait --for=condition=Ready externalsecret/api-secrets --timeout=120s

# 4. Run migrations using the release's API image. Stop if the Job fails.
kubectl apply -f kops/migration-job.yaml
# Substitute the SAME release-specific Job name here.
kubectl -n agribridge wait --for=condition=complete job/api-migrate-replace-release-id --timeout=330s

# 5. Deploy only after successful migration.
kubectl apply -f kops/api-deployment.yaml
kubectl -n agribridge rollout status deployment/api --timeout=600s
kubectl apply -f kops/web-deployment.yaml
kubectl -n agribridge rollout status deployment/web --timeout=600s

# 6. Expose the ready application over HTTPS.
kubectl apply -f kops/ingress.yaml
kubectl -n agribridge get pods,services,ingress,jobs
```

Run each stage only after the previous stage succeeds. In CI/CD, enforce those
exit codes so a failed secret sync, migration or rollout blocks the next stage.
For failures, inspect `kubectl -n agribridge describe job/JOB_NAME` and
`kubectl -n agribridge logs job/JOB_NAME`. Retain release Jobs long enough for
diagnosis, then delete old ones under a deliberate retention policy.

No demo users are created: `SEED_DEMO_DATA=false`. A fresh database will not have
the Compose demo logins. Plan a separate, controlled account bootstrap before an
interactive demo; never enable demo seeding in production.

Traffic follows DNS → ALB → worker NodePort → Service-selected Pod. `/api`
goes directly to API without stripping its prefix; `/version` also goes to API.
Other paths go to web. API `/healthz`, `/readyz` and `/metrics` have no public API
Ingress routes; Kubernetes probes and internal monitoring access them directly.
Web has its own `/healthz`. A web-only port-forward serves static files but does
not reproduce the ALB's API routing or HTTPS session-cookie behavior.

ALB terminates HTTPS with ACM, so there is no Kubernetes TLS Secret here. Backend
traffic is HTTP within the VPC; use private networking and appropriate security
groups. Nginx in the web container serves assets; a separate Nginx Ingress
Controller is not required for this ALB design.

## Updates, autoscaling and remaining work

- ConfigMap and Secret changes do not restart pods automatically. After applying
  configuration or waiting for rotated secrets to sync, restart the affected
  Deployment and wait for its rollout. Nginx needs a restart to load new config.
  Coordinate DB credential rotation with the actual database user.
- Keep schema migrations compatible with the old and new API during a rolling
  update. Application rollback never rolls back SQL or restores lost data.
- Once `kubectl top pods -n agribridge` works, optionally apply
  `kops/hpa.yaml`. HPA scales pods, not EC2 workers. After enabling HPA,
  remove `spec.replicas` from the Deployment files so later applies do not reset
  its replica count. Configure cluster capacity/scaling separately.
- Add CNI-enforced NetworkPolicies after confirming the kOps CNI, VPC/data-service
  CIDRs and how ALB NodePort source addresses appear at pods. Security groups are
  still required. No pod-level network isolation is implemented by these files.
- Controller installation, cluster/instance-group definitions, infrastructure,
  DNS automation, monitoring, backup/restore and account bootstrap remain separate
  implementation steps. Cluster YAML needs the actual region, zones, cluster DNS,
  kOps state store, Kubernetes version, CNI and instance sizing.
- Existing architecture images still show the earlier Helm proposal. This folder
  is the current plain-YAML implementation; Helm can be introduced later.

Controller references: [ALB annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/)
and [ESO AWS Secrets Manager](https://external-secrets.io/latest/provider/aws-secrets-manager/).

## Validation performed

All 14 YAML files parse successfully. Static consistency checks passed for the
16 resources, including selectors, Service ports, Ingress backends, resource
references, string-valued configuration, probe ports, HPA targets and matching
API/migration images. Git whitespace checks passed.

Full Kubernetes/ESO schema validation and runtime checks have not been performed.
The schema validator download was blocked by unavailable network DNS, and Docker
socket access was denied in this session. Nothing was applied to a cluster.
After replacing placeholders and installing the required CRDs, use
`kubectl apply --dry-run=server -f PATH` against the intended cluster for each
stage before applying it, then verify migrations, rollouts and HTTPS login.
