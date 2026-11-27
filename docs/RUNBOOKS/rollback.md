# Roll back a production image

Argo CD tracks `main` and syncs `helm/agribridge/values-production.yaml`.
`selfHeal` puts the cluster back if you only change it with `kubectl` or
`helm rollback`. The rollback that survives `selfHeal` is a commit.

Set both `tag` lines in `helm/agribridge/values-production.yaml` back to the
previous image SHA and push that commit to `main` with `[skip ci]` in the
message. Argo CD syncs the older image. A revert of the tag commit that does
not contain `[skip ci]` starts a new build and, after the next approval,
writes a new tag.

Refresh before the 60 second reconcile:

```sh
kubectl -n argocd annotate application agribridge argocd.argoproj.io/refresh=hard --overwrite
```

Confirm the running build:

```sh
curl -fsS https://production.agribridge.deuces.dev/version
```

`gitSha` and `imageTag` match the image that is running.

After a deploy, the same host is the smoke check:

```sh
./tests/smoke/health.sh https://production.agribridge.deuces.dev
```
