# Stage 7 monitoring review — 2 November 2026

Historical record: the cluster was shut down on 2 November 2026. The changes
below are now retained in source; no additional live upgrade is claimed here.
This review records the earlier deployment. The deployment is now offline;
see the current [project status](../../README.md).

Status at the review: live baseline and synthetic alert demonstration verified. Two source
fixes are prepared locally and tested. No platform apply or source publication
has been performed for these fixes. A refreshed saved Terraform plan is needed
before the monitoring Helm upgrade decision.

## Verified baseline

- Prometheus has 30 active targets: 27 up, 3 down. All five AgriBridge API
  targets are up: staging 2, production 3. Their build-info metrics identify
  the verified second release from workflow 41473944213.
- API server, kubelets, CoreDNS, node-exporter and kube-state-metrics targets
  are up. All three down targets are kube-proxy connection refusals on 10249.
  Controller-manager and scheduler jobs have no discovered targets and their
  default missing-target alerts are firing. The component pods themselves are
  Running; scrape health and application health are distinct observations.
- Grafana /api/health reports database ok. Its default Prometheus datasource
  is provisioned with UID prometheus and the correct internal Service URL.
  A query from the Grafana pod returns 2 staging and 3 production API targets.
  Logged-in dashboard viewing remains to be captured.
- A fresh request to /version in each environment used request ID
  stage7-8b451a47-d064-489b-ba43-2d27e8cdef45. AWS FilterLogEvents found both
  resulting HTTP 200 API records in /agribridge/containers with the correct
  staging/production Kubernetes namespace metadata. This verifies live
  request-to-Fluent-Bit-to-CloudWatch delivery, beyond stream existence.
- A uniquely named temporary PrometheusRule in monitoring produced an info
  alert without an application outage. Observed firing in Prometheus and
  Alertmanager, then inactive/resolved in both. The temporary rule was deleted.
  Alertmanager's only receiver was null with no external integration, so this
  demonstrates internal alert delivery, not email/Slack notification delivery.

Raw non-secret observations and the alert cleanup receipt are retained privately
under .runtime/observability/.

## Proposed fixes

| Source | Change | Result |
|---|---|---|
| helm/agribridge/templates/monitoring.yaml | Filter availability by release namespace, add missing-target fallback, label/describe that namespace | A staging outage is detected while production remains healthy; missing targets also alert after the existing 2-minute period |
| monitoring/prometheus-values.yaml | Disable controller-manager, scheduler and kube-proxy collectors whose endpoints this kOps deployment does not expose to these scrapers | Remove unsupported scrape/missing-job alerts; those component metrics remain unmonitored by this configuration |

The monitoring change keeps the pinned chart, database volumes, retention,
Grafana persistence and working collectors. Enabling the excluded component
metrics later requires suitable kOps endpoint/discovery configuration and a
separate cluster-change review.

Validation passed: 13 GitOps/release/render checks, Helm lint, and four live
PromQL-engine cases. The rendered new expression is inactive for healthy staging,
fires for simulated staging-down while production is healthy, and fires when
staging targets are absent. The old unscoped expression misses the simulated
staging-only outage. Both environment renders have the correct namespace labels.

## Apply and publication sequence

1. Run bash scripts/plan-platform.sh from the project root in the normal terminal.
   This saves a plan and applies nothing. Review the actual artifact; expect an
   in-place monitoring Helm values update. Existing Argo CD remains enabled.
2. After reviewing/approving the exact plan, apply its saved artifact. Check
   working targets and the remaining active alerts; Watchdog is intentionally
   always firing.
3. Review and approve publication of the corrected application alert through
   GitOps. Publishing chart source to main triggers the normal checked release
   to staging and production. Verify both loaded alert rules use their respective
   namespace and the missing-target fallback. Keep other local evidence edits
   separate unless included in that concrete publication review.
4. Open Grafana locally, choose the Prometheus datasource and demonstrate
   application requests, latency, current build and Kubernetes workload metrics.
   Record screenshots for capstone evidence without exposing credentials.

The proposed changes request no new instance, load balancer or persistent volume.
Existing compute, storage, traffic and logging usage continues. Source fixes are
not live until their respective Terraform and GitOps deployment steps complete.
