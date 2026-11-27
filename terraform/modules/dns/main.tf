locals {
  # Apex and wildcard names are known at plan time. ACM fills in the validation
  # CNAME values during apply. for_each stays on these names so the instance
  # keys do not wait on the certificate.
  certificate_domains = toset([
    var.zone_name,
    "*.${var.zone_name}",
  ])
}

resource "aws_route53_zone" "app" {
  name = var.zone_name
}

resource "aws_acm_certificate" "app" {
  domain_name               = var.zone_name
  subject_alternative_names = ["*.${var.zone_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  for_each = local.certificate_domains

  zone_id = aws_route53_zone.app.zone_id
  name = one([
    for option in aws_acm_certificate.app.domain_validation_options : option.resource_record_name
    if option.domain_name == each.value
  ])
  type = one([
    for option in aws_acm_certificate.app.domain_validation_options : option.resource_record_type
    if option.domain_name == each.value
  ])
  records = [one([
    for option in aws_acm_certificate.app.domain_validation_options : option.resource_record_value
    if option.domain_name == each.value
  ])]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}
