locals {
  instance_create          = var.instance.create
  instance_lifecyle_ignore = var.instance.lifecyle_ignore
  instance_subnet_id       = var.instance.subnet_id
  instance = {
    ami                                = local.ami_id
    associate_public_ip_address        = var.instance.associate_public_ip_address
    availability_zone                  = var.instance.availability_zone
    capacity_reservation_specification = var.instance.capacity_reservation_specification
    cpu_options                        = var.instance.cpu_options
    credit_specification               = var.instance.credit_specification
    disable_api_stop = coalesce(
      var.instance.disable_api_stop,
      !var.instance.enable_api_stop,
    )
    disable_api_termination = coalesce(
      var.instance.disable_api_termination,
      !var.instance.enable_api_termination,
    )
    ebs_block_device = coalesce(
      var.instance.ebs_block_device,
      var.instance.ebs_block_devices,
    )
    ebs_optimized   = var.instance.ebs_optimized
    enclave_options = var.instance.enclave_options
    ephemeral_block_device = coalesce(
      var.instance.ephemeral_block_device,
      var.instance.ephemeral_block_devices,
    )
    get_password_data       = var.instance.get_password_data
    hibernation             = var.instance.hibernation
    host_id                 = var.instance.host_id
    host_resource_group_arn = var.instance.host_resource_group_arn
    iam_instance_profile = (
      local.iam_instance_profile_name != null
      ? local.iam_instance_profile_name
      : var.instance.iam_instance_profile
    )
    instance_initiated_shutdown_behavior = var.instance.instance_initiated_shutdown_behavior
    instance_market_options              = var.instance.instance_market_options
    instance_type                        = var.instance.instance_type
    ipv6_address_count                   = var.instance.ipv6_address_count
    ipv6_addresses                       = var.instance.ipv6_addresses
    key_name = try(
      aws_key_pair.this[0].id,
      local.provisioner_key_name,
    )
    launch_template     = var.instance.launch_template
    maintenance_options = var.instance.maintenance_options
    metadata_options    = var.instance.metadata_options
    monitoring          = var.instance.monitoring
    network_interface = coalesce(
      var.instance.network_interface,
      var.instance.network_interfaces,
    )
    placement_group            = var.instance.placement_group
    placement_partition_number = var.instance.placement_partition_number
    private_dns_name_options   = var.instance.private_dns_name_options
    private_ip                 = var.instance.private_ip
    root_block_device          = var.instance.root_block_device
    secondary_private_ips      = var.instance.secondary_private_ips
    source_dest_check          = var.instance.source_dest_check
    subnet_id                  = local.instance_subnet_id
    tenancy                    = var.instance.tenancy
    user_data = var.instance.user_data_base64 == null ? try(
      coalesce(var.instance.user_data, local.provisioning_userdata),
      null,
    ) : null
    user_data_base64            = var.instance.user_data_base64
    user_data_replace_on_change = var.instance.user_data_replace_on_change
    volume_tags                 = coalesce(var.instance.volume_tags, local.tags)
    tags = coalesce(var.instance.tags, merge({
      Name = local.name
    }, local.tags))
    vpc_security_group_ids = concat(
      compact([one(aws_security_group.default[*].id)]),
      var.instance.vpc_security_group_ids,
    )
  }
}

resource "static_data" "aws_instance" {
  data = {
    for key, value in local.instance :
    key => jsonencode(value)
    if contains(local.instance_lifecyle_ignore, key)
  }
  triggers = {
    instance_lifecyle_ignore = jsonencode(local.instance_lifecyle_ignore)
  }
}

locals {
  instance_input = merge(local.instance, {
    for key, value in static_data.aws_instance.output : key => jsondecode(value)
  })
  instance_input_block = merge(
    local.instance_input,
    {
      # shallow single blocks
      for key in [
        "cpu_options",
        "credit_specification",
        "enclave_options",
        "instance_market_options",
        "launch_template",
        "maintenance_options",
        "metadata_options",
        "private_dns_name_options",
        "root_block_device",
        ] : key => (
        local.instance_input[key] == null
        ? {}
        : { "${key}" = local.instance_input[key] }
      )
    },
    # single blocks with nested blocks
    {
      capacity_reservation_specification = (
        local.instance_input.capacity_reservation_specification == null
        ? {}
        : {
          capacity_reservation_specification = merge(
            local.instance_input.capacity_reservation_specification,
            {
              capacity_reservation_target = (
                local.instance_input.capacity_reservation_specification.capacity_reservation_target == null
                ? {}
                : {
                  capacity_reservation_target = local.instance_input.capacity_reservation_specification.capacity_reservation_target
                }
              )
            },
          )
        }
      )
      instance_market_options = (
        local.instance_input.instance_market_options == null
        ? {}
        : {
          instance_market_options = merge(
            local.instance_input.instance_market_options,
            {
              spot_options = (
                local.instance_input.instance_market_options.spot_options == null
                ? {}
                : {
                  spot_options = local.instance_input.instance_market_options.spot_options
                }
              )
            },
          )
        }
      )
    },
  )
  instance_lookup = anytrue([
    local.eip.create,
    local.dns_create,
    local.provisioner_requires_access_ip,
  ])
  instance_id = try(
    aws_instance.this[0].id,
    var.instance.id,
  )
}

resource "aws_instance" "this" {
  count = local.instance_create ? 1 : 0
  depends_on = [
    aws_s3_bucket.ansible_s3_provisioning,
    aws_s3_object.ansible_s3_provisioning,
    aws_iam_role_policy.ansible_s3_provisioning,
    aws_iam_role.this,
    aws_iam_role_policy_attachment.this,
    aws_iam_instance_profile.this,
    aws_security_group.default,
    aws_security_group_rule.default_egress,
    aws_security_group_rule.egress,
    aws_security_group_rule.ingress,
    aws_security_group_rule.provisioner,
  ]

  ami                                  = local.instance_input.ami
  associate_public_ip_address          = local.instance_input.associate_public_ip_address
  availability_zone                    = local.instance_input.availability_zone
  disable_api_stop                     = local.instance_input.disable_api_stop
  disable_api_termination              = local.instance_input.disable_api_termination
  ebs_optimized                        = local.instance_input.ebs_optimized
  get_password_data                    = local.instance_input.get_password_data
  hibernation                          = local.instance_input.hibernation
  host_id                              = local.instance_input.host_id
  host_resource_group_arn              = local.instance_input.host_resource_group_arn
  iam_instance_profile                 = local.instance_input.iam_instance_profile
  instance_initiated_shutdown_behavior = local.instance_input.instance_initiated_shutdown_behavior
  instance_type                        = local.instance_input.instance_type
  ipv6_address_count                   = local.instance_input.ipv6_address_count
  ipv6_addresses                       = local.instance_input.ipv6_addresses
  key_name                             = local.instance_input.key_name
  monitoring                           = local.instance_input.monitoring
  placement_group                      = local.instance_input.placement_group
  placement_partition_number           = local.instance_input.placement_partition_number
  private_ip                           = local.instance_input.private_ip
  secondary_private_ips                = local.instance_input.secondary_private_ips
  source_dest_check                    = local.instance_input.source_dest_check
  subnet_id                            = local.instance_input.subnet_id
  tags                                 = local.instance_input.tags
  tenancy                              = local.instance_input.tenancy
  user_data                            = local.instance_input.user_data
  user_data_base64                     = local.instance_input.user_data_base64
  user_data_replace_on_change          = local.instance_input.user_data_replace_on_change
  vpc_security_group_ids               = local.instance_input.vpc_security_group_ids

  dynamic "capacity_reservation_specification" {
    for_each = local.instance_input_block.capacity_reservation_specification
    content {
      capacity_reservation_preference = capacity_reservation_specification.value.capacity_reservation_preference

      dynamic "capacity_reservation_target" {
        for_each = capacity_reservation_specification.value.capacity_reservation_target
        content {
          capacity_reservation_id                 = capacity_reservation_target.value.capacity_reservation_id
          capacity_reservation_resource_group_arn = capacity_reservation_target.value.capacity_reservation_resource_group_arn
        }
      }
    }
  }

  dynamic "cpu_options" {
    for_each = local.instance_input_block.cpu_options
    content {
      amd_sev_snp      = cpu_options.value.amd_sev_snp
      core_count       = cpu_options.value.core_count
      threads_per_core = cpu_options.value.threads_per_core
    }
  }

  dynamic "credit_specification" {
    for_each = local.instance_input_block.credit_specification
    content {
      cpu_credits = credit_specification.value.cpu_credits
    }
  }

  dynamic "ebs_block_device" {
    for_each = local.instance_input_block.ebs_block_device
    content {
      device_name           = coalesce(ebs_block_device.value.device_name, ebs_block_device.key)
      delete_on_termination = ebs_block_device.value.delete_on_termination
      encrypted             = ebs_block_device.value.encrypted
      iops                  = ebs_block_device.value.iops
      kms_key_id            = ebs_block_device.value.kms_key_id
      snapshot_id           = ebs_block_device.value.snapshot_id
      tags                  = ebs_block_device.value.tags
      throughput            = ebs_block_device.value.throughput
      volume_size           = ebs_block_device.value.volume_size
      volume_type           = ebs_block_device.value.volume_type
    }
  }

  dynamic "enclave_options" {
    for_each = local.instance_input_block.enclave_options
    content {
      enabled = enclave_options.value.enabled
    }
  }

  dynamic "ephemeral_block_device" {
    for_each = local.instance_input_block.ephemeral_block_device
    content {
      device_name  = coalesce(ephemeral_block_device.value.device_name, ephemeral_block_device.key)
      no_device    = ephemeral_block_device.value.no_device
      virtual_name = ephemeral_block_device.value.virtual_name
    }
  }

  dynamic "instance_market_options" {
    for_each = local.instance_input_block.instance_market_options
    content {
      market_type = instance_market_options.value.market_type

      dynamic "spot_options" {
        for_each = instance_market_options.value.spot_options
        content {
          instance_interruption_behavior = spot_options.value.instance_interruption_behavior
          max_price                      = spot_options.value.max_price
          spot_instance_type             = spot_options.value.spot_instance_type
          valid_until                    = spot_options.value.valid_until
        }
      }
    }
  }

  dynamic "launch_template" {
    for_each = local.instance_input_block.launch_template
    content {
      id      = launch_template.value.id
      name    = launch_template.value.name
      version = launch_template.value.version
    }
  }

  dynamic "maintenance_options" {
    for_each = local.instance_input_block.maintenance_options
    content {
      auto_recovery = maintenance_options.value.auto_recovery
    }
  }

  dynamic "metadata_options" {
    for_each = local.instance_input_block.metadata_options
    content {
      http_endpoint               = metadata_options.value.http_endpoint
      http_protocol_ipv6          = metadata_options.value.http_protocol_ipv6
      http_put_response_hop_limit = metadata_options.value.http_put_response_hop_limit
      http_tokens                 = metadata_options.value.http_tokens
      instance_metadata_tags      = metadata_options.value.instance_metadata_tags
    }
  }

  dynamic "network_interface" {
    for_each = local.instance_input_block.network_interface
    content {
      delete_on_termination = network_interface.value.delete_on_termination
      device_index          = network_interface.value.device_index
      network_card_index    = network_interface.value.network_card_index
      network_interface_id  = network_interface.value.network_interface_id
    }
  }

  dynamic "private_dns_name_options" {
    for_each = local.instance_input_block.private_dns_name_options
    content {
      enable_resource_name_dns_aaaa_record = private_dns_name_options.value.enable_resource_name_dns_aaaa_record
      enable_resource_name_dns_a_record    = private_dns_name_options.value.enable_resource_name_dns_a_record
      hostname_type                        = private_dns_name_options.value.hostname_type
    }
  }

  dynamic "root_block_device" {
    for_each = local.instance_input_block.root_block_device
    content {
      delete_on_termination = root_block_device.value.delete_on_termination
      encrypted             = root_block_device.value.encrypted
      iops                  = root_block_device.value.iops
      kms_key_id            = root_block_device.value.kms_key_id
      tags                  = root_block_device.value.tags
      throughput            = root_block_device.value.throughput
      volume_size           = root_block_device.value.volume_size
      volume_type           = root_block_device.value.volume_type
    }
  }

  lifecycle {
    precondition {
      condition     = local.instance.launch_template == null ? local.instance.instance_type != null : true
      error_message = "An `instance_type` must be set if not using a launch template."
    }
  }
}

data "aws_instance" "this" {
  count = local.instance_lookup ? 1 : 0
  depends_on = [
    aws_instance.this,
    aws_eip.this,
    time_sleep.eip_attach,
  ]

  instance_id = local.instance_id
}

locals {
  instance_ref = try(
    data.aws_instance.this[0],
    aws_instance.this[0],
    null,
  )
  instance_public_ip = try(
    aws_eip.this[0].public_ip,
    local.instance_ref.public_ip,
    null,
  )
  instance_private_ip = try(
    local.instance_ref.private_ip,
    null,
  )
  instance_access_ip = try(coalesce(
    local.instance_public_ip,
    local.instance_private_ip,
  ), null)
}
