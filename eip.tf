locals {
  eip = {
    create                    = var.eip.create
    address                   = var.eip.address
    associate_with_private_ip = var.eip.associate_with_private_ip
    customer_owned_ipv4_pool  = var.eip.customer_owned_ipv4_pool
    domain                    = var.eip.domain
    network_border_group      = var.eip.network_border_group
    public_ipv4_pool          = var.eip.public_ipv4_pool
    attach_duration           = var.eip.attach_duration
    # TODO: network_interface
  }
}

resource "aws_eip" "this" {
  count = local.eip.create ? 1 : 0

  instance = local.instance_id

  address                   = local.eip.address
  associate_with_private_ip = local.eip.associate_with_private_ip
  customer_owned_ipv4_pool  = local.eip.customer_owned_ipv4_pool
  domain                    = local.eip.domain
  network_border_group      = local.eip.network_border_group
  public_ipv4_pool          = local.eip.public_ipv4_pool
}

resource "time_sleep" "eip_attach" {
  count = local.eip.create ? 1 : 0
  depends_on = [
    aws_eip.this,
  ]

  triggers = {
    id = aws_eip.this[0].id,
  }

  create_duration = local.eip.attach_duration
}
