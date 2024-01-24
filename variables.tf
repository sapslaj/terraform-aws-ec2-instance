variable "ami" {
  type = object({
    id      = optional(string)
    family  = optional(string, "ubuntu")
    version = optional(string, "jammy-22.04")
    arch    = optional(string, "amd64")
  })
  nullable = false
  default  = {}
}

variable "ansible" {
  type = object({
    paths        = optional(list(string), [])
    roles        = optional(any, [])
    playbook     = optional(any)
    requirements = optional(any)
    args         = optional(string, "")
    s3 = optional(object({
      create_provisioning_bucket            = optional(bool)
      create_provisioning_bucket_objects    = optional(bool)
      create_provisioning_bucket_iam_policy = optional(bool)
      provisioning_bucket_name              = optional(string)
      provisioning_bucket_name_prefix       = optional(string)
      set_hostname                          = optional(bool, true)
    }))
    ssh = optional(object({
      set_hostname = optional(bool, true)
    }))
  })
  nullable = true
  default  = null
}

variable "cloudwatch" {
  type = object({
    metric_alarms = optional(list(string), ["instance_status_check", "system_status_check"])
  })
  nullable = false
  default  = {}
}

variable "dns" {
  type = object({
    create   = optional(bool, false)
    hostname = optional(string)
    domain   = optional(string)
    type     = optional(string, "A")
    ttl      = optional(number, 60)
    provider = optional(string, "route53")
    route53 = optional(object({
      hosted_zone_name = optional(string)
      hosted_zone_id   = optional(string)
    }))
  })
  nullable = false
  default  = {}
}

variable "eip" {
  type = object({
    create                    = optional(bool, false)
    address                   = optional(string)
    associate_with_private_ip = optional(bool)
    customer_owned_ipv4_pool  = optional(string)
    domain                    = optional(string, "vpc")
    network_border_group      = optional(string)
    public_ipv4_pool          = optional(string)
  })
  nullable = false
  default  = {}
}

variable "iam" {
  type = object({
    create_role                  = optional(bool, false)
    create_instance_profile      = optional(bool, false)
    attach_default_policies      = optional(bool, false)
    managed_policies             = optional(map(string), {})
    role_name                    = optional(string)
    role_name_prefix             = optional(string)
    instance_profile_name        = optional(string)
    instance_profile_name_prefix = optional(string)
  })
  nullable = false
  default  = {}
}

variable "name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "instance" {
  type = object({
    create          = optional(bool, true)
    id              = optional(string)
    lifecyle_ignore = optional(list(string), [])

    ami                         = optional(string)
    associate_public_ip_address = optional(bool)
    availability_zone           = optional(string)
    capacity_reservation_specification = optional(object({
      capacity_reservation_preference = optional(string)
      capacity_reservation_target = optional(object({
        capacity_reservation_id                 = optional(string)
        capacity_reservation_resource_group_arn = optional(string)
      }))
    }))
    cpu_options = optional(object({
      amd_sev_snp      = optional(string)
      core_count       = optional(number)
      threads_per_core = optional(number)
    }))
    credit_specification = optional(object({
      cpu_credits = optional(string)
    }))
    enable_api_stop         = optional(bool, true)
    disable_api_stop        = optional(bool)
    enable_api_termination  = optional(bool, true)
    disable_api_termination = optional(bool)
    ebs_block_device        = optional(any)
    ebs_block_devices = optional(map(object({
      delete_on_termination = optional(bool)
      device_name           = optional(string)
      encrypted             = optional(bool)
      iops                  = optional(number)
      kms_key_id            = optional(string)
      snapshot_id           = optional(string)
      tags                  = optional(map(string))
      throughput            = optional(number)
      volume_size           = optional(number)
      volume_type           = optional(string)
    })), {})
    ebs_optimized = optional(bool)
    enclave_options = optional(object({
      enabled = optional(bool)
    }))
    ephemeral_block_device = optional(any)
    ephemeral_block_devices = optional(map(object({
      device_name  = optional(string)
      no_device    = optional(bool)
      virtual_name = optional(string)
    })), {})
    get_password_data                    = optional(bool)
    hibernation                          = optional(bool)
    host_id                              = optional(string)
    host_resource_group_arn              = optional(string)
    iam_instance_profile                 = optional(string)
    instance_initiated_shutdown_behavior = optional(string)
    instance_market_options = optional(object({
      market_type = optional(string)
      spot_options = optional(object({
        instance_interruption_behavior = optional(string)
        max_price                      = optional(string)
        spot_instance_type             = optional(string)
        valid_until                    = optional(string)
      }))
    }))
    instance_type      = optional(string)
    ipv6_address_count = optional(number)
    ipv6_addresses     = optional(list(string))
    key_name           = optional(string)
    launch_template = optional(object({
      id      = optional(string)
      name    = optional(string)
      version = optional(string)
    }))
    maintenance_options = optional(object({
      auto_recovery = optional(string)
    }))
    metadata_options = optional(object({
      http_endpoint               = optional(string)
      http_protocol_ipv6          = optional(string)
      http_put_response_hop_limit = optional(number)
      http_tokens                 = optional(string)
      instance_metadata_tags      = optional(bool)
    }))
    monitoring        = optional(bool)
    network_interface = optional(any)
    network_interfaces = optional(map(object({
      delete_on_termination = optional(bool)
      device_index          = number
      network_card_index    = optional(number)
      network_interface_id  = string
    })), {})
    placement_group            = optional(string)
    placement_partition_number = optional(number)
    private_dns_name_options = optional(object({
      enable_resource_name_dns_aaaa_record = optional(bool)
      enable_resource_name_dns_a_record    = optional(bool)
      hostname_type                        = optional(string)
    }))
    private_ip = optional(string)
    root_block_device = optional(object({
      delete_on_termination = optional(bool)
      encrypted             = optional(bool)
      iops                  = optional(number)
      kms_key_id            = optional(string)
      tags                  = optional(map(string))
      throughput            = optional(number)
      volume_size           = optional(number)
      volume_type           = optional(string)
    }))
    secondary_private_ips       = optional(list(string))
    source_dest_check           = optional(bool)
    subnet_id                   = optional(string)
    tags                        = optional(map(string))
    tenancy                     = optional(string)
    user_data                   = optional(string)
    user_data_base64            = optional(string)
    user_data_replace_on_change = optional(bool)
    volume_tags                 = optional(map(string))
    security_group_ids          = optional(list(string))
    vpc_security_group_ids      = optional(list(string), [])
  })
  nullable = false
  default  = {}
}

variable "provisioner" {
  type = object({
    method             = optional(string)
    force              = optional(bool, false)
    username           = optional(string)
    create_key_pair    = optional(bool)
    create_public_key  = optional(bool)
    create_private_key = optional(bool)
    public_key         = optional(string)
    private_key        = optional(string)
    key_name           = optional(string)
    key_name_prefix    = optional(string)
    ip_provider        = optional(string, "https://checkip.amazonaws.com")
    connection_timeout = optional(string, "1m")
  })
  nullable = false
  default  = {}
}

variable "security_group" {
  type = object({
    create                          = optional(bool, true)
    create_default_egress_rule      = optional(bool, true)
    create_default_provisioner_rule = optional(bool)
    vpc_id                          = optional(string)
    name                            = optional(string)
    name_prefix                     = optional(string)
    description                     = optional(string)
    ingresses = optional(map(object({
      port                     = optional(number)
      from_port                = optional(number)
      to_port                  = optional(number)
      protocol                 = optional(string, "tcp")
      description              = optional(string)
      cidr_blocks              = optional(list(string))
      ipv6_cidr_blocks         = optional(list(string))
      prefix_list_ids          = optional(list(string))
      source_security_group_id = optional(string)
      self                     = optional(bool)
    })), {})
    egresses = optional(map(object({
      port                     = optional(number)
      from_port                = optional(number)
      to_port                  = optional(number)
      protocol                 = optional(string, "tcp")
      description              = optional(string)
      cidr_blocks              = optional(list(string))
      ipv6_cidr_blocks         = optional(list(string))
      prefix_list_ids          = optional(list(string))
      source_security_group_id = optional(string)
      self                     = optional(bool)
    })), {})
  })
  nullable = false
  default  = {}
}
