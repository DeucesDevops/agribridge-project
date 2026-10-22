# Publish application images to Docker Hub

The [Publish Docker images workflow](../.github/workflows/publish-images.yml) builds
and publishes the existing API and web runtime targets to public Docker Hub repositories:

- [macroni607/agribridge-api](https://hub.docker.com/r/macroni607/agribridge-api)
- [macroni607/agribridge-web](https://hub.docker.com/r/macroni607/agribridge-web)

It runs when application source or the workflow changes on `dev` or `main`, and can
also be started manually from GitHub Actions once the workflow exists on the default
branch. Pull requests run the checks but cannot publish images or access the publishing
secret. This workflow publishes images; it does not deploy Kubernetes or cloud resources.

## Checks before publication

Both lockfiles are installed with `npm ci`. Both components are linted; the existing
warning-level style rules remain warnings. API unit coverage must meet the existing 70%
domain gate. Integration tests run against an ephemeral PostgreSQL database, separate
from local/demo data. Web unit tests, coverage and its Vite production build also run.
JUnit XML and coverage output are retained as Actions artifacts for 14 days.

The existing dependency audit findings documented in the local-development guide remain
outstanding. This publishing workflow does not claim a complete security or deployment
pipeline and does not silently upgrade dependencies.

## Credentials and public repositories

The repository variable `DOCKERHUB_USERNAME` identifies the Docker Hub account. The
repository Actions secret `DOCKERHUB_TOKEN` contains a dedicated publishing personal access
token with repository write permission (which includes read), without delete permission.
The token is supplied only to the Docker login step, never as an image build argument.
The initial token is named `agribridge-github-actions-2026-10-22` and expires on
20 January 2027. Its expiration and revocation are managed in Docker account settings;
replace the GitHub secret when rotating it. No local `.env` or application credentials are uploaded.

Both Docker Hub repositories must be public. The publishing job checks their visibility
without authentication after pushing. Configure each repository deliberately rather than
relying on an account's default visibility.

## Tags, architectures and reuse

Each runtime image supports **linux/amd64** and **linux/arm64**. The workflow rebuilds from
the committed source; it does not upload an old, uncommitted local development image.

- `sha-<full Git commit>` identifies the source of a build. These tags are intended to
  remain unchanged, though Docker Hub tags are technically mutable unless repository
  tag-immutability rules are configured.
- `dev` or `main` points to the most recent successful build from that branch.
- The digest printed in the Actions summary identifies the exact published artifact.
  Use the digest when promoting or deploying an image.

```sh
docker pull macroni607/agribridge-api:dev
docker pull macroni607/agribridge-web:dev
```

The API `/version` reports the package version, source commit, build date and SHA tag.
OCI labels identify both images. Application passwords, hosts and feature settings still
belong in runtime configuration. The local Compose file continues to build local images;
using registry images in a deployed environment is a separate deployment decision.

Actions are pinned to verified commit SHAs. Update those pins deliberately when adopting
new action releases. The existing Dockerfiles and pinned base-image digests are reused.
