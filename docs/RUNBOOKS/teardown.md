# Tear down

`scripts/teardown-environment.sh` removes the environment. A plain
`terraform destroy` is the wrong first command. Argo CD owns the application.
While that Application exists, `selfHeal` recreates the Ingress. Delete the
Application first, while Argo CD is still running, so the finalizer removes
the Ingress and the load balancer can release the subnets. ExternalDNS is set
to `upsert-only`, so it does not delete the records it created, and the hosted
zone then refuses to delete. The kOps state bucket and the discovery bucket
have `prevent_destroy` set, so a destroy that still has them in state stops
there on purpose.

```sh
export GITHUB_TOKEN=...
export KOPS_STATE_STORE=s3://kops-state-607
./scripts/teardown-environment.sh
```

`GITHUB_TOKEN` is a credential. Export it in the shell. Do not commit it.

The script keeps `s3://kops-state-607`, `s3://agribridge-oidc-237258628535`,
and the Terraform state bucket. Delete the state bucket only after you no
longer need the state:

```sh
aws s3 rb s3://agribridge-tfstate-ACCOUNT_ID --force
```

If destroy stops because the platform module is still recorded and the API is
already gone:

```sh
terraform -chdir=terraform/environments/production state rm 'module.platform["production"]'
terraform -chdir=terraform/environments/production destroy -var install_platform=false
```
