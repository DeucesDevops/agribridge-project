# Guides

| Guide | Purpose |
|---|---|
| [SETUP.md](SETUP.md) | Build the local app, the kOps cluster and the pipeline, in order |
| [PIPELINE.md](PIPELINE.md) | What each CI/CD job does, and which GitHub settings it needs |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Request path, GitOps pipeline, cluster, and the diagram |

[SETUP.md](SETUP.md) describes the Terraform layout. A rebuild starts with
`scripts/bootstrap-state.sh`, then `terraform/environments/production`.

Start with the root [README](../README.md) if you only want the application running
on your machine.
