locals {
  iam_create_role = coalesce(
    var.iam.create_role,
    local.provisioner_requires_iam_role,
  )
  iam_create_instance_profile = coalesce(
    var.iam.create_instance_profile,
    local.iam_create_role,
  )
  iam_attach_default_policies = coalesce(
    var.iam.attach_default_policies,
    local.iam_create_role,
  )
  iam_role_managed_policies = var.iam.managed_policies

  iam_role_name_prefix             = coalesce(var.iam.role_name_prefix, substr(local.name, 0, 38))
  iam_role_name                    = try(aws_iam_role.this[0].name, var.iam.role_name)
  iam_instance_profile_name_prefix = coalesce(var.iam.instance_profile_name_prefix, local.iam_role_name_prefix)
  iam_instance_profile_name        = try(aws_iam_instance_profile.this[0].name, var.iam.instance_profile_name)

  iam_default_policies = {
    "AmazonSSMManagedInstanceCore" = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = local.iam_create_role ? 1 : 0

  name               = var.iam.role_name
  name_prefix        = var.iam.role_name == null ? local.iam_role_name_prefix : null
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
  tags = coalesce(var.iam.tags, merge({
    Name = local.name
  }, local.tags))
}

resource "aws_iam_instance_profile" "this" {
  count = local.iam_create_instance_profile ? 1 : 0

  name = var.iam.instance_profile_name_prefix == null ? coalesce(
    var.iam.instance_profile_name,
    var.instance.iam_instance_profile,
    local.iam_role_name,
  ) : null
  name_prefix = var.iam.instance_profile_name_prefix
  role        = local.iam_role_name
  tags = coalesce(var.iam.tags, merge({
    Name = local.name
  }, local.tags))
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = merge(
    local.iam_attach_default_policies ? local.iam_default_policies : {},
    local.iam_role_managed_policies,
  )

  role       = local.iam_role_name
  policy_arn = each.value
}
