output "zone_id" {
  description = "Public hosted zone id."
  value       = aws_route53_zone.app.zone_id
}

output "zone_arn" {
  description = "Public hosted zone ARN. ExternalDNS is allowed to change records in this zone."
  value       = aws_route53_zone.app.arn
}

output "name_servers" {
  description = "Name servers to delegate at the registrar for the parent domain."
  value       = aws_route53_zone.app.name_servers
}

output "certificate_arn" {
  description = "Validated ACM certificate ARN for the zone apex and wildcard."
  value       = aws_acm_certificate_validation.app.certificate_arn
}
