locals {
  create_security_group = coalesce(
    var.security_group.create,
    local.provisioner_requires_provisioner_sg_rule,
  )
  create_security_group_default_egress_rule = (
    local.create_security_group
    ? var.security_group.create_default_egress_rule
    : false
  )
  create_security_group_default_provisioner_rule = (
    local.create_security_group
    ? coalesce(var.security_group.create_default_provisioner_rule, local.provisioner_requires_provisioner_sg_rule)
    : false
  )

  security_group_ingresses   = local.create_security_group ? var.security_group.ingresses : {}
  security_group_egresses    = local.create_security_group ? var.security_group.egresses : {}
  security_group_name        = var.security_group.name
  security_group_name_prefix = coalesce(var.security_group.name_prefix, local.name)
  security_group_description = coalesce(var.security_group.description, "Default security group for ${local.name}")

  security_group_vpc_id = try(data.aws_subnet.this[0].vpc_id, var.security_group.vpc_id)
}

data "aws_subnet" "this" {
  count = (local.instance_subnet_id != null && var.security_group.vpc_id == null) ? 1 : 0

  id = local.instance_subnet_id
}

resource "aws_security_group" "default" {
  count = local.create_security_group ? 1 : 0

  vpc_id      = local.security_group_vpc_id
  name        = local.security_group_name
  name_prefix = local.security_group_name == null ? local.security_group_name_prefix : null
  description = local.security_group_description
  tags = coalesce(var.security_group.tags, merge({
    Name = local.name
  }, local.tags))
}

resource "aws_security_group_rule" "default_egress" {
  count = local.create_security_group_default_egress_rule ? 1 : 0

  security_group_id = aws_security_group.default[0].id
  description       = "default egress"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

resource "aws_security_group_rule" "provisioner" {
  count = local.create_security_group_default_provisioner_rule ? 1 : 0

  security_group_id = aws_security_group.default[0].id
  description       = "provisioner"
  type              = "ingress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["${trimspace(data.http.provisioner_ip[0].response_body)}/32"]
}

resource "aws_security_group_rule" "ingress" {
  for_each = local.security_group_ingresses

  type              = "ingress"
  security_group_id = aws_security_group.default[0].id
  description       = coalesce(each.value.description, each.key)

  from_port = coalesce(each.value.from_port, each.value.port)
  to_port   = coalesce(each.value.to_port, each.value.port)

  protocol                 = each.value.protocol
  cidr_blocks              = each.value.cidr_blocks
  ipv6_cidr_blocks         = each.value.ipv6_cidr_blocks
  prefix_list_ids          = each.value.prefix_list_ids
  self                     = each.value.self
  source_security_group_id = each.value.source_security_group_id
}

resource "aws_security_group_rule" "egress" {
  for_each = local.security_group_egresses

  type              = "egress"
  security_group_id = aws_security_group.default[0].id
  description       = coalesce(each.value.description, each.key)

  from_port = coalesce(each.value.from_port, each.value.port)
  to_port   = coalesce(each.value.to_port, each.value.port)

  protocol                 = each.value.protocol
  cidr_blocks              = each.value.cidr_blocks
  ipv6_cidr_blocks         = each.value.ipv6_cidr_blocks
  prefix_list_ids          = each.value.prefix_list_ids
  self                     = each.value.self
  source_security_group_id = each.value.source_security_group_id
}
