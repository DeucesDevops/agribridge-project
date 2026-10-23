# Repository structure

This layout follows the simplified bootcamp project plan. Existing application and local Docker files stay in their current locations. Plain application Kubernetes manifests now live under `kops/`. Terraform, Helm, workflows and monitoring remain placeholders.

```text
agribridge-project/
├── api/                       # Existing Express API, tests and Dockerfile
├── web/                       # Existing React application, Nginx and Dockerfile
├── terraform/                 # AWS infrastructure configuration
├── kops/                      # Plain YAML for the kOps deployment (Helm deferred)
│   ├── README.md
│   ├── api-configmap.yaml
│   ├── api-deployment.yaml
│   ├── api-service.yaml
│   ├── externalsecret.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── migration-job.yaml
│   ├── namespace.yaml
│   ├── poddisruptionbudgets.yaml
│   ├── secretstore.yaml
│   ├── serviceaccount.yaml
│   ├── web-configmap.yaml
│   ├── web-deployment.yaml
│   └── web-service.yaml
├── helm/
│   └── agribridge/             # One application chart for multiple environments
│       └── templates/         # Application Kubernetes resource templates
├── .github/
│   └── workflows/             # GitHub Actions validation and deployment
├── monitoring/                # Metrics and logging configuration
├── scripts/
│   ├── local.sh               # Existing local startup and management
│   ├── check-local.sh         # Existing local checks
│   └── verify-local.py        # Existing application verification
├── docs/
│   ├── architecture/          # Existing diagrams and generation prompts
│   ├── local-development.md   # Existing Docker setup instructions
│   └── repository-structure.md
├── compose.yaml               # Existing local Docker Compose definition
├── .gitignore
└── README.md
```

Keep `compose.yaml` as the Compose entry point. Add files and subdirectories as their implementation stages require them. Use the [kOps manifest guide](../kops/README.md) for plain Kubernetes deployment. All Kubernetes definition files live directly in `kops/`, with no subfolders.

Helm is deferred for now. If introduced later, add `Chart.yaml`, shared `values.yaml`, and environment values to `helm/agribridge/`, with templates in its existing `templates/` directory.
