output "ami" {
  value = merge(
    var.ami,
    try(data.aws_ami.this[0], {}),
    {
      lookup = {
        lookup = local.ami_lookup
        name   = local.ami_lookup_name[local.ami_family]
        owners = local.ami_lookup_owners[local.ami_family]
      }
      default_username = local.ami_default_username[local.ami_family]
      id               = local.ami_id
    }
  )
}

output "ansible" {
  value = merge(
    var.ansible,
    {
      paths         = local.ansible_paths
      filenames     = local.ansible_filenames
      hashes        = local.ansible_hashes
      roles         = local.ansible_roles
      playbook      = yamldecode(local.ansible_playbook)
      playbook_yaml = local.ansible_playbook
      s3 = {
        provisioning                                       = local.ansible_s3_provisioning
        set_hostname                                       = local.ansible_s3_set_hostname
        create_provisioning_bucket                         = local.ansible_s3_create_provisioning_bucket
        create_provisioning_bucket_objects                 = local.ansible_s3_create_provisioning_bucket_objects
        create_provisioning_bucket_iam_policy              = local.ansible_s3_create_provisioning_bucket_iam_policy
        provisioning_bucket_name_prefix                    = local.ansible_s3_provisioning_bucket_name_prefix
        provisioning_bucket_name                           = local.ansible_s3_provisioning_bucket_name
        provisioning_bucket_arn                            = local.ansible_s3_provisioning_bucket_arn
        aws_s3_bucket                                      = one(aws_s3_bucket.ansible_s3_provisioning[*])
        aws_s3_bucket_public_access_block                  = one(aws_s3_bucket_public_access_block.ansible_s3_provisioning[*])
        aws_s3_bucket_server_side_encryption_configuration = one(aws_s3_bucket_server_side_encryption_configuration.ansible_s3_provisioning[*])
        aws_s3_objects                                     = aws_s3_object.ansible_s3_provisioning
        aws_iam_policy_document_provisioning               = one(data.aws_iam_policy_document.ansible_s3_provisioning[*].json)
        aws_iam_role_policy                                = one(aws_iam_role_policy.ansible_s3_provisioning[*])
        user_data                                          = local.ansible_s3_provisioning_user_data
      }
      ssh = {
        provisioning         = local.ansible_ssh_provisioning
        provisioner_triggers = local.ansible_ssh_provisioner_triggers
        set_hostname         = local.ansible_ssh_set_hostname
      }
    }
  )
}

output "cloudwatch" {
  value = {
    metric_alarms = {
      instance_status_check = one(aws_cloudwatch_metric_alarm.instance_status_check[*])
      system_status_check   = one(aws_cloudwatch_metric_alarm.system_status_check[*])
    }
  }
}

output "dns" {
  value = {
    create   = local.dns_create
    hostname = local.dns_hostname
    domain   = local.dns_domain
    type     = local.dns_type
    ttl      = local.dns_ttl
    records  = local.dns_records
    provider = local.dns_provider
    route53 = {
      provider         = local.dns_provider_route53
      create           = local.dns_route53_create
      hosted_zone_name = local.dns_route53_hosted_zone_name
      hosted_zone_id   = local.dns_route53_hosted_zone_id
      hosted_zone      = one(data.aws_route53_zone.this[*])
      record           = one(aws_route53_record.this[*])
    }
  }
}

output "eip" {
  value = merge(
    var.eip,
    try(aws_eip.this[0], {}),
  )
}

output "iam" {
  value = merge(
    var.iam,
    {
      role_name_prefix             = local.iam_role_name_prefix
      role_name                    = local.iam_role_name
      instance_profile_name_prefix = local.iam_instance_profile_name_prefix
      instance_profile_name        = local.iam_instance_profile_name
      default_policies             = local.iam_default_policies
      ec2_assume_role_policy       = data.aws_iam_policy_document.ec2_assume_role_policy.json
      role                         = one(aws_iam_role.this[*])
      instance_profile             = one(aws_iam_instance_profile.this[*])
      policy_attachments           = aws_iam_role_policy_attachment.this
    }
  )
}

output "name" {
  value = local.name
}

output "tags" {
  value = local.tags
}

output "instance" {
  value = merge(
    var.instance,
    try(aws_instance.this[0], {}),
    {
      id          = local.instance_id,
      static_data = static_data.aws_instance
      input       = local.instance_input
      access_ip   = local.instance_access_ip
    }
  )
}

output "provisioner" {
  value = merge(
    var.provisioner,
    {
      method                       = local.provisioning_method
      force                        = local.provisioner_force
      ip_provider                  = local.provisioner_ip_provider
      supplies_user_data           = local.provisioner_supplies_user_data
      requires_key_pair            = local.provisioner_requires_key_pair
      requires_provisioner_sg_rule = local.provisioner_requires_provisioner_sg_rule
      username                     = local.provisioner_username
      userdata                     = local.provisioning_userdata
      triggers                     = local.provisioner_triggers
      host                         = local.provisioner_host
      create_key_pair              = local.provisioner_create_key_pair
      create_private_key           = local.provisioner_create_private_key
      create_pubic_key             = local.provisioner_create_public_key
      key_name                     = local.provisioner_key_name
      key_name_prefix              = local.provisioner_key_name_prefix
      private_key                  = local.provisioner_private_key
      public_key                   = local.provisioner_public_key
      tls_private_key              = one(tls_private_key.this[*])
      tls_public_key               = one(data.tls_public_key.this[*])
      aws_key_pair                 = one(aws_key_pair.this[*])
      provisioner_ip_data          = one(data.http.provisioner_ip)
      provisioner_ip               = local.provisioner_ip
    }
  )
}

output "security_group" {
  value = merge(
    var.security_group,
    {
      create                          = local.create_security_group
      create_default_egress_rule      = local.create_security_group_default_egress_rule
      create_default_provisioner_rule = local.create_security_group_default_provisioner_rule
      ingresses                       = local.security_group_ingresses
      egresses                        = local.security_group_egresses
      name                            = local.security_group_name
      name_prefix                     = local.security_group_name_prefix
      description                     = local.security_group_description
    },
    try(aws_security_group.default[0], {}),
  )
}
