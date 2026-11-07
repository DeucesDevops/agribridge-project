# Delegate agribridge.deuces.dev

Bootstrap recreated public Route 53 zone `Z098670523YNOQ1LDBYDG`. Its nameservers
were independently checked through AWS APIs on 2 November 2026.

Update the NS record set for the `agribridge` subdomain in the authoritative
parent zone for `deuces.dev`, replacing the four values from the deleted zone.
Bernard approved subdomain delegation during the earlier session. The current
parent records have not been verified in this resumed session.

| Type | Host in the deuces.dev parent zone | Nameserver | TTL |
|---|---|---|---|
| NS | agribridge | ns-1354.awsdns-41.org | Automatic/default |
| NS | agribridge | ns-2037.awsdns-62.co.uk | Automatic/default |
| NS | agribridge | ns-292.awsdns-36.com | Automatic/default |
| NS | agribridge | ns-944.awsdns-54.net | Automatic/default |

If `deuces.dev` still uses Namecheap BasicDNS, PremiumDNS or FreeDNS, open
Domain List -> deuces.dev -> Manage -> Advanced DNS -> Host Records. Review any
existing `agribridge` delegation and conflicting records before saving a change.
Replace a stale delegation for this subdomain with the complete new four-server
set. Do not put these in the registrar's nameserver field for the entire domain,
and do not change unrelated host records.

If the domain uses third-party authoritative nameservers, make the change with
that DNS provider instead. Namecheap documents its
[record setup](https://www.namecheap.com/support/knowledgebase/article.aspx/434/2237/how-do-i-set-up-host-records-for-a-domain/)
and [NS record type](https://www.namecheap.com/support/knowledgebase/article.aspx/579/2237/which-record-type-option-should-i-choose-for-the-information-im-about-to-enter/).

After the approved change, validate from a normal terminal:

```sh
dig +short NS deuces.dev
dig +short NS agribridge.deuces.dev
```

The child query should return exactly the four new AWS nameservers, ignoring
order and trailing dots. Confirm the delegation in the parent zone and check the
SOA directly against the new AWS servers before creating the DNS-based cluster.
Propagation can take time according to existing cache TTLs.

Status: new records prepared; replacement of the parent delegation and public
DNS verification remain pending. No parent DNS records have been modified by
this resumed session. Shell DNS-over-HTTPS failed to resolve the resolver host;
the web retrieval tool also could not fetch its response. These failures are
session limitations, not evidence that the public delegation is incorrect.

After saving the parent records, run `make plan-cluster` from the project root.
It compares public NS results with the current Terraform outputs and stops if
they differ. On success, it saves kOps metadata and a bootstrap-state backup in
S3 and generates a reviewable Terraform plan. It does not apply cluster nodes.
