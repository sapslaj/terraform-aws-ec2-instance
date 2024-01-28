locals {
  provisioning_method = lower(coalesce(
    var.provisioner.method,
    try(var.ansible.s3, null) != null ? "ansible_s3" : null,
    try(var.ansible, null) != null ? "ansible_ssh" : null,
    "user_data",
  ))
  provisioner_force              = var.provisioner.force
  provisioner_ip_provider        = var.provisioner.ip_provider
  provisioner_connection_timeout = var.provisioner.connection_timeout

  provisioner_supplies_user_data = {
    ansible_s3  = true
    ansible_ssh = false
    user_data   = false
  }[local.provisioning_method]
  provisioner_requires_key_pair = {
    ansible_s3  = false
    ansible_ssh = true
    user_data   = false
  }[local.provisioning_method]
  provisioner_requires_access_ip = {
    ansible_s3  = false
    ansible_ssh = true
    user_data   = false
  }[local.provisioning_method]
  provisioner_requires_provisioner_sg_rule = {
    ansible_s3  = false
    ansible_ssh = true
    user_data   = false
  }[local.provisioning_method]
  provisioner_requires_iam_role = {
    ansible_s3  = true
    ansible_ssh = false
    user_data   = false
  }[local.provisioning_method]

  provisioner_username = coalesce(
    var.provisioner.username,
    lookup(local.ami_default_username, var.ami.family, "root"),
  )
  provisioning_userdata = local.provisioner_supplies_user_data ? {
    ansible_s3 = local.ansible_s3_provisioning_user_data
  }[local.provisioning_method] : null

  provisioner_triggers = {
    dns_hostname      = local.dns_hostname
    provisioner_force = local.provisioner_force ? timestamp() : ""
  }

  provisioner_host = try(coalesce(
    (var.provisioner.access.use_public_ip ? local.instance_public_ip : null),
    (var.provisioner.access.use_private_ip ? local.instance_private_ip : null),
  ), local.instance_access_ip)

  provisioner_instance_key_name_given = var.instance.key_name != null
  provisioner_create_key_pair = coalesce(
    var.provisioner.create_key_pair,
    (local.provisioner_instance_key_name_given ? false : null),
    local.provisioner_requires_key_pair,
  )
  provisioner_create_private_key = coalesce(
    var.provisioner.create_private_key,
    (var.provisioner.private_key != null ? false : null),
    local.provisioner_create_key_pair,
  )
  provisioner_create_public_key = coalesce(
    var.provisioner.create_public_key,
    (var.provisioner.public_key != null ? false : null),
    local.provisioner_create_key_pair,
  )
  provisioner_key_name = (
    var.instance.key_name != null
    ? var.instance.key_name
    : var.provisioner.key_name
  )
  provisioner_key_name_prefix = (
    local.provisioner_key_name == null
    ? (
      var.provisioner.key_name_prefix == null
      ? local.name
      : var.provisioner.key_name_prefix
    )
    : null
  )
}

resource "tls_private_key" "this" {
  count = local.provisioner_create_private_key ? 1 : 0

  algorithm = "ED25519"
}

locals {
  provisioner_private_key = try(
    tls_private_key.this[0].private_key_openssh,
    sensitive(var.provisioner.private_key),
  )
}

data "tls_public_key" "this" {
  count = local.provisioner_create_public_key ? 1 : 0

  private_key_openssh = local.provisioner_private_key
}

locals {
  provisioner_public_key = try(
    data.tls_public_key.this[0].public_key_openssh,
    var.provisioner.public_key,
  )
}

resource "aws_key_pair" "this" {
  count = local.provisioner_create_key_pair ? 1 : 0

  key_name        = local.provisioner_key_name
  key_name_prefix = local.provisioner_key_name_prefix
  public_key      = local.provisioner_public_key
}

data "http" "provisioner_ip" {
  count = local.create_security_group_default_provisioner_rule ? 1 : 0

  url = local.provisioner_ip_provider
}

locals {
  provisioner_ip = try(trimspace(data.http.provisioner_ip[0].response_body), null)
}
