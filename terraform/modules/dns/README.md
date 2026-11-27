# DNS

Creates the public Route 53 zone and the ACM certificate for the apex and
`*.<zone>`, plus the validation CNAMEs. The production root passes `zone_name`
and publishes `zone_id`, `name_servers`, and `certificate_arn`.

Validation records use `for_each` over the apex and wildcard names, which are
known at plan time. ACM supplies the CNAME target during apply. The apex and
the wildcard often share one validation name. `allow_overwrite` keeps the
second record from failing when AWS returns the same CNAME for both.

Delegate `name_servers` at the registrar before certificate validation can
succeed. This module has no provider or backend blocks.
