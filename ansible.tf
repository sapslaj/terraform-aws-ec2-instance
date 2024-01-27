locals {
  ansible_paths = concat(["${path.module}/ansible"], try(var.ansible.paths, []))
  ansible_filenames = {
    for f in flatten([
      for ansible_path in local.ansible_paths : [
        for file in fileset(ansible_path, "**") : {
          filename = file
          filepath = join("/", [ansible_path, file])
        }
      ]
    ]) : f.filename => f.filepath
  }
  ansible_directories = distinct([for filename in keys(local.ansible_filenames) : dirname(filename)])

  ansible_hashes = {
    for filename, filepath in local.ansible_filenames : filename => filemd5(filepath)
  }

  ansible_roles = try(var.ansible.roles, [])

  ansible_playbook = (
    try(var.ansible.playbook, null) == null
    ? yamlencode([{
      hosts      = "localhost"
      connection = "local"
      become     = true
      roles      = local.ansible_roles
    }])
    : (
      can(yamldecode(try(var.ansible.playbook, "[]")))
      ? try(var.ansible.playbook, "[]")
      : yamlencode(try(var.ansible.playbook, []))
    )
  )

  ansible_requirements = (
    try(var.ansible.requirements, null) == null
    ? ""
    : (
      can(yamldecode(var.ansible.requirements))
      ? tostring(var.ansible.requirements)
      : yamlencode(var.ansible.requirements)
    )
  )

  ansible_args = try(var.ansible.args, "")
}

locals {
  ansible_ssh_provisioner_triggers = merge(local.provisioner_triggers, {
    instance_id          = local.instance_id
    provisioner_username = local.provisioner_username
    instance_access_ip   = local.instance_access_ip
  })
  ansible_ssh_set_hostname = try(var.ansible.ssh.set_hostname, true)
  ansible_ssh_provisioning = local.provisioning_method == "ansible_ssh"
}

resource "terraform_data" "ansible_ssh_provisioner_init" {
  count = local.ansible_ssh_provisioning ? 1 : 0

  triggers_replace = merge(local.ansible_ssh_provisioner_triggers, {
    hostname            = local.dns_hostname
    ansible_directories = jsonencode(local.ansible_directories)
  })

  connection {
    user        = local.provisioner_username
    host        = local.provisioner_host
    private_key = local.provisioner_private_key
    timeout     = local.provisioner_connection_timeout
  }

  provisioner "remote-exec" {
    inline = concat(
      local.ansible_ssh_set_hostname ? ["sudo hostnamectl set-hostname ${local.dns_hostname}"] : [],
      [
        "sudo mkdir -p /var/ansible",
        "sudo chown -R $USER:$USER /var/ansible",
      ],
    )
  }

  provisioner "remote-exec" {
    inline = [
      for dir in local.ansible_directories : "mkdir -p '/var/ansible/${dir}'"
    ]
  }
}

resource "terraform_data" "ansible_ssh_provisioner_clean" {
  count = local.ansible_ssh_provisioning ? 1 : 0
  depends_on = [
    terraform_data.ansible_ssh_provisioner_init,
  ]

  triggers_replace = merge(local.ansible_ssh_provisioner_triggers, {
    ansible_filenames = md5(jsonencode(local.ansible_filenames))
  })

  connection {
    user        = local.provisioner_username
    host        = local.provisioner_host
    private_key = local.provisioner_private_key
    timeout     = local.provisioner_connection_timeout
  }

  provisioner "file" {
    content = join("\n", formatlist("/var/ansible/%s", concat(
      keys(local.ansible_filenames),
      ["main.yml", "requirements.yml"],
    )))
    destination = "/tmp/ansible-filelist"
  }

  provisioner "remote-exec" {
    script = "${path.module}/ansible_ssh_provisioner_clean.sh"
  }
}

resource "terraform_data" "ansible_ssh_provisioner_upload" {
  for_each = local.ansible_ssh_provisioning ? local.ansible_filenames : {}
  depends_on = [
    terraform_data.ansible_ssh_provisioner_clean,
  ]

  input = {
    connection = {
      user        = local.provisioner_username
      host        = local.provisioner_host
      private_key = local.provisioner_private_key
      timeout     = local.provisioner_connection_timeout
    }
  }

  triggers_replace = merge(local.ansible_ssh_provisioner_triggers, {
    hash        = filemd5(each.value)
    source      = each.value
    destination = "/var/ansible/${each.key}"
  })

  connection {
    user        = self.output.connection.user
    host        = self.output.connection.host
    private_key = self.output.connection.private_key
    timeout     = self.output.connection.timeout
  }

  provisioner "file" {
    source      = each.value
    destination = "/var/ansible/${each.key}"
  }
}

resource "terraform_data" "ansible_ssh_provisioner_run" {
  count = local.ansible_ssh_provisioning ? 1 : 0
  depends_on = [
    terraform_data.ansible_ssh_provisioner_upload,
  ]

  triggers_replace = merge(local.ansible_ssh_provisioner_triggers, {
    ansible_filenames    = md5(jsonencode(local.ansible_filenames))
    ansible_hashes       = md5(jsonencode(local.ansible_hashes))
    ansible_requirements = md5(local.ansible_requirements)
    ansible_playbook     = md5(local.ansible_playbook)
    ansible_args         = local.ansible_args
  })

  connection {
    user        = local.provisioner_username
    host        = local.provisioner_host
    private_key = local.provisioner_private_key
    timeout     = local.provisioner_connection_timeout
  }

  provisioner "file" {
    content     = local.ansible_requirements
    destination = "/var/ansible/requirements.yml"
  }

  provisioner "file" {
    content     = local.ansible_playbook
    destination = "/var/ansible/main.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /var/ansible/bootstrap-self.sh",
      "sudo bash /var/ansible/bootstrap-self.sh ${local.ansible_args}",
    ]
  }
}

locals {
  ansible_s3_provisioning = local.provisioning_method == "ansible_s3"
  ansible_s3_set_hostname = try(var.ansible.s3.set_hostname, true)
  ansible_s3_create_provisioning_bucket = coalesce(
    try(var.ansible.s3.create_provisioning_bucket, null),
    local.ansible_s3_provisioning,
  )
  ansible_s3_create_provisioning_bucket_objects = coalesce(
    try(var.ansible.s3.create_provisioning_bucket_objects, null),
    local.ansible_s3_create_provisioning_bucket,
  )
  ansible_s3_create_provisioning_bucket_iam_policy = coalesce(
    try(var.ansible.s3.create_provisioning_bucket_iam_policy, null),
    local.ansible_s3_create_provisioning_bucket,
  )
  ansible_s3_provisioning_bucket_name_prefix = try(var.ansible.s3.provisioning_bucket_name_prefix, "${substr(local.name, 0, 24)}-provisioning")
  ansible_s3_provisioning_bucket_name = coalesce(
    one(aws_s3_bucket.ansible_s3_provisioning[*].id),
    try(var.ansible.s3.provisioning_bucket_name, null),
    "[MISSING]",
  )
  ansible_s3_provisioning_bucket_arn = try(
    aws_s3_bucket.ansible_s3_provisioning[0].arn,
    "arn:aws:s3:::${local.ansible_s3_provisioning_bucket_name}",
  )
  ansible_s3_provisioner_triggers = merge(local.provisioner_triggers, {
    ansible_filenames = md5(jsonencode(local.ansible_filenames))
    ansible_hashes    = md5(jsonencode(local.ansible_hashes))
    ansible_playbook  = md5(local.ansible_playbook)
  })
}

check "provisioning_s3_bucket_name" {
  assert {
    condition = local.ansible_s3_provisioning ? alltrue([
      length(compact([local.ansible_s3_provisioning_bucket_name])) != 0,
      local.ansible_s3_provisioning_bucket_name != "[MISSING]",
    ]) : true
    error_message = "S3 bucket must be configured or created when used with the ansible_s3 provisioning method."
  }
}

resource "aws_s3_bucket" "ansible_s3_provisioning" {
  count = local.ansible_s3_create_provisioning_bucket ? 1 : 0

  bucket        = try(var.ansible.s3.provisioning_s3_bucket_name, null)
  bucket_prefix = try(var.ansible.s3.provisioning_s3_bucket_name, null) == null ? local.ansible_s3_provisioning_bucket_name_prefix : null

  force_destroy = true
  tags = merge(local.tags, {
    Name = coalesce(try(var.ansible.s3.provisioning_s3_bucket_name, null), "${local.name}-provisioning")
  })
}

resource "aws_s3_bucket_public_access_block" "ansible_s3_provisioning" {
  count = local.ansible_s3_create_provisioning_bucket ? 1 : 0

  bucket = one(aws_s3_bucket.ansible_s3_provisioning[*].id)

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ansible_s3_provisioning" {
  count = local.ansible_s3_create_provisioning_bucket ? 1 : 0

  bucket = one(aws_s3_bucket.ansible_s3_provisioning[*].id)

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "ansible_s3_provisioning" {
  for_each = local.ansible_s3_create_provisioning_bucket_objects ? local.ansible_filenames : {}

  bucket = local.ansible_s3_provisioning_bucket_name
  key    = each.key
  source = each.value
  etag   = filemd5(each.value)
  tags = merge({
    Name = "${local.name}-provisioning-${each.value}"
  }, local.tags)
}

data "aws_iam_policy_document" "ansible_s3_provisioning" {
  count = local.ansible_s3_create_provisioning_bucket_iam_policy ? 1 : 0

  statement {
    actions = [
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:GetObjectTagging",
      "s3:GetObjectVersion",
    ]
    resources = [
      local.ansible_s3_provisioning_bucket_arn,
      "${local.ansible_s3_provisioning_bucket_arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "ansible_s3_provisioning" {
  count = local.ansible_s3_create_provisioning_bucket_iam_policy ? 1 : 0

  name   = "ansible-s3-provisioning"
  role   = local.iam_role_name
  policy = data.aws_iam_policy_document.ansible_s3_provisioning[0].json
}

locals {
  ansible_s3_provisioning_user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    %{for name, value in local.ansible_s3_provisioner_triggers}
    # ${name} = ${value}
    %{endfor}
    %{if local.ansible_s3_set_hostname}
    if command -v hostnamectl &>/dev/null ; then
      hostnamectl set-hostname '${local.dns_hostname}'
    else
      echo '${local.dns_hostname}' > /etc/hostname
    fi
    %{endif}
    mkdir -p /var/ansible
    aws s3 cp --recursive s3://${local.ansible_s3_provisioning_bucket_name}/ /var/ansible
    base64 --decode > /var/ansible/requirements.yml <<<'${base64encode(local.ansible_requirements)}'
    base64 --decode > /var/ansible/main.yml <<<'${base64encode(local.ansible_playbook)}'
    chmod +x /var/ansible/bootstrap-self.sh
    bash /var/ansible/bootstrap-self.sh ${local.ansible_args}
  EOT
}
