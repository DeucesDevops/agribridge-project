# Identity

GitHub Actions OIDC, the CI role that can read the kOps state bucket, and the
IRSA roles for External Secrets, ExternalDNS, and the production backup
CronJob. When `manage_github` is true, this module also writes the Actions
variables and the `production` environment reviewer.

The kOps issuer, the zone, the backup bucket, and the secrets are inputs from
the production root. IRSA trust uses the kOps issuer and the audience
`amazonaws.com`, which is what the pod-identity webhook puts on the token.
The load balancer controller and the EBS driver roles stay in the cluster
module, because kOps renders them.

`for_each` keys are the static names `github`, `production`, the IRSA map
keys, and the Actions variable names. ARNs are values, not keys.

The GitHub and AWS providers are configured in the production root. This
module has no provider or backend blocks. `GITHUB_TOKEN` is an environment
variable for the provider. It is not a Terraform variable and it is not
committed.
