# Domain and DNS

Verified on 16 November 2026 against the authenticated Namecheap Advanced DNS
page and AWS Route 53. The required Namecheap delegation already matched; no
registrar records needed changing.

| Responsibility | Configuration |
|---|---|
| Domain provider | Namecheap, `deuces.dev` |
| Parent DNS | Existing Namecheap DNS; preserve unrelated hosts and mail |
| Child zone | Route 53 `agribridge.deuces.dev`, ID `Z098670523YNOQ1LDBYDG` |
| Delegation | Four NS records at Namecheap with host `agribridge` |
| Staging | `staging.agribridge.deuces.dev` → ingress load balancer |
| Production | `production.agribridge.deuces.dev` → same ingress load balancer |
| HTTPS | ACM certificate and DNS validation managed by Terraform |

The four nameservers are `ns-1354.awsdns-41.org`, `ns-2037.awsdns-62.co.uk`,
`ns-292.awsdns-36.com` and `ns-944.awsdns-54.net`. Do not replace the whole
`deuces.dev` nameserver configuration: only the AgriBridge child zone is delegated.

The child zone currently retains its NS, SOA and ACM validation CNAME. Application
routing records were absent during this inspection; no Kubernetes nodes were
running. Restoring the platform creates its load balancer and the two application
CNAMEs through `module.platform.aws_route53_record.app`. Do not invent a target
or point those names at the `kops` management instance.

After platform apply, check:

```sh
dig +short NS agribridge.deuces.dev
dig +short CNAME staging.agribridge.deuces.dev
dig +short CNAME production.agribridge.deuces.dev
curl --fail https://staging.agribridge.deuces.dev/readyz
curl --fail https://production.agribridge.deuces.dev/readyz
```

A DNS record alone does not establish application health. ACM validation and a
healthy ingress deployment must complete before HTTPS verification can pass.
