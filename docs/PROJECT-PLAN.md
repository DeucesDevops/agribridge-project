# AgriBridge delivery plan

The README is the assessment specification. The selected platform is kOps on EC2
in us-east-1, with Route 53 under agribridge.deuces.dev. EKS is not used.

| Stage | Deliverable | Completion evidence |
|---|---|---|
| 1 | Multi-stage, non-root API and web images; Compose PostgreSQL and Redis | Images build; login works through one origin; integration suite uses real PostgreSQL |
| 2 | kOps cluster rendered to Terraform; remote locked state; IAM, DNS, ACM, ECR, Secrets Manager | Terraform apply succeeds and subsequent plan has no changes; Kubernetes nodes Ready |
| 3 | One Helm chart, separate staging/production namespaces, EBS PostgreSQL persistence, runtime secrets | Both releases ready, secret sync healthy, same image identities |
| 4 | GitHub Actions checks, image publication, staging then production deployment | Successful run URL; JUnit and coverage artifacts; failed checks block delivery |
| 5 | Prometheus/Grafana metrics, CloudWatch logs, backup and recovery | Metrics scraped; logs ingested; S3 backup restored into an isolated database |
| 6 | Operational acceptance | Redis loss degrades without restart loop; DB restart preserves data; rollback and runbook verified |

Implementation is tracked in Git. Verification results and limitations belong in
`docs/VERIFICATION.md`; unexecuted checks must not be described as successful.
