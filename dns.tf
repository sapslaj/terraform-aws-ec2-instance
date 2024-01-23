locals {
  dns_create = var.dns.create
  dns_domain = var.dns.domain
  dns_hostname = coalesce(
    var.dns.hostname,
    join(".", compact([local.name, local.dns_domain])),
  )
  dns_type = var.dns.type
  dns_ttl  = var.dns.ttl
  dns_records = {
    "A" = [local.instance_access_ip]
  }[local.dns_type]
  dns_provider                 = var.dns.provider
  dns_provider_route53         = local.dns_provider == "route53"
  dns_route53_create           = local.dns_create && local.dns_provider_route53
  dns_route53_hosted_zone_name = try(var.dns.route53.hosted_zone_name, local.dns_domain)
  dns_route53_hosted_zone_id   = try(var.dns.route53.hosted_zone_id, null)
}

data "aws_route53_zone" "this" {
  count = (local.dns_route53_create && local.dns_route53_hosted_zone_id == null) ? 1 : 0

  name = local.dns_route53_hosted_zone_name
}

resource "aws_route53_record" "this" {
  count = local.dns_route53_create ? 1 : 0

  zone_id = coalesce(one(data.aws_route53_zone.this[*].zone_id), local.dns_route53_hosted_zone_id)
  name    = local.dns_hostname
  type    = local.dns_type
  ttl     = local.dns_ttl
  records = local.dns_records
}
