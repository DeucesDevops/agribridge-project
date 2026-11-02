# AWS bootstrap review — stage 3

Stage 2 passed locally on 1 November 2026. This document prepares the first AWS
change for review; it is not evidence of a successful Terraform plan or apply.

## First batch

Use account `237258628535`, region `us-east-1`, with the existing bootstrap
configuration in `terraform/bootstrap/`. The provider now rejects a different
account through `expected_account_id` (an input for reuse in another account).

| Resource | Purpose |
|---|---|
| `agribridge-tfstate-237258628535` | Encrypted, versioned, private Terraform state; deny non-TLS access |
| `kops-state-607` | Encrypted, versioned, private kOps configuration/state |
| `agribridge-oidc-237258628535` | Publicly readable OIDC discovery documents for workload identity; never store secret material here |
| Public Route 53 zone `agribridge.deuces.dev` | DNS for the new cluster and application |

These are 13 Terraform resource declarations including bucket configuration and
policy resources. The actual creation/update/deletion counts must come from a
fresh plan. The previous local state is retained and may describe deleted
resources; refresh must establish the current remote state. Do not discard state
or manually recreate infrastructure to work around it.

The read-only AWS inventory found no buckets and no `agribridge.deuces.dev` zone.
The unrelated `taskflow.deuces.dev` zone and the two stopped legacy EC2 instances
are outside this batch. No EC2 instances, load balancers, databases or secrets
are created by bootstrap.

## Generate the actual plan

From a normal Mac terminal with AWS credentials and network access:

```sh
cd /Users/bernardboateng/Projects/DevOps/agribridge-project
make plan-bootstrap
```

This copies any existing local bootstrap state into a private timestamped recovery
file, initializes providers using the lockfile, validates, refreshes resource
reads, and saves a binary plan plus readable text under the ignored `.runtime/`
folder. It does not apply, import or change AWS resources. It can download
Terraform providers and changes local initialization files.

Review the saved text and plan summary before approving an apply. Resolve any
unexpected updates or deletions first. If an object already exists but is missing
from state, review an import separately. No `-auto-approve` step is included.
The agent's restricted shell cannot reach the Terraform provider registry/STS,
so provider-backed planning must run in the normal terminal in this session.

## Cost and later dependencies

A standard public hosted zone is listed at $0.50/month for the first 25 zones,
plus chargeable DNS queries. S3 storage and requests are usage-based. See the
[official Route 53 pricing](https://aws.amazon.com/route53/pricing/) and
[S3 pricing](https://aws.amazon.com/s3/pricing/). This batch does not start the
cluster's compute costs. Review a separate full cost estimate before approving
cluster creation.

The later cluster specification requests three t3.medium nodes. A read-only AWS
Price List API query on 1 November returned $0.0416 per Linux shared-tenancy
on-demand instance-hour in us-east-1: $2.9952/day for three continuously running
instances, before storage, IPv4 addresses, load balancing, traffic, logs, taxes or
CPU-surplus charges. This is a compute subtotal, not the complete project cost.
AWS also confirmed that the pinned Canonical Ubuntu image is available in the
region (`ami-052355af2a014bd2c`). Generated kOps resource and volume sizes still
need review before the cluster plan can be approved.

After an approved bootstrap apply, use its actual name-server output to delegate
only `agribridge.deuces.dev` from the authoritative DNS provider for `deuces.dev`.
Do not replace the parent domain's nameservers without a separate DNS decision.
Validate delegation before attempting the DNS-based kOps cluster.

Five old secret entries remain marked for deletion. Resolve restore/import or
replacement naming before planning application services; do not fetch or print
secret values. No secret recovery is included in bootstrap approval.

Terraform's `prevent_destroy` guards on the state buckets and hosted zone remain
in place. Later teardown requires an explicit decision about retaining them;
stopping compute does not remove storage and DNS charges.
