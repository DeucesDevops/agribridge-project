# Repository structure

This layout follows the simplified bootcamp project plan. Existing application and local Docker files stay in their current locations. Later-stage directories contain `.gitkeep` placeholders so Git can track them; their infrastructure, charts, workflows, and monitoring configuration have not been implemented yet.

```text
agribridge-project/
├── api/                       # Existing Express API, tests and Dockerfile
├── web/                       # Existing React application, Nginx and Dockerfile
├── terraform/                 # AWS infrastructure configuration
├── kops/                      # Cluster and instance-group definitions
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

Keep `compose.yaml` as the Compose entry point. Add files and subdirectories as their implementation stages require them. No separate raw Kubernetes directory, per-service Terraform modules, or additional chart copies are needed at this stage.

When implementing Helm, add `Chart.yaml`, shared `values.yaml`, and environment values to `helm/agribridge/`. Keep the templates in its existing `templates/` directory.
