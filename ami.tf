locals {
  ami_family = var.ami.family
  ami_lookup = alltrue([
    var.instance.ami == null,
    var.instance.launch_template == null,
    var.ami.id == null,
  ])
  ami_lookup_name = {
    ubuntu = ["ubuntu/images/hvm-ssd/ubuntu-${var.ami.version}-${var.ami.arch}-server-*"]
  }
  ami_lookup_owners = {
    ubuntu = ["099720109477"]
  }
  ami_default_username = {
    ubuntu = "ubuntu"
  }
}

data "aws_ami" "this" {
  count = local.ami_lookup ? 1 : 0

  most_recent = true
  owners      = local.ami_lookup_owners[local.ami_family]

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "name"
    values = local.ami_lookup_name[local.ami_family]
  }
}

locals {
  ami_id = try(coalesce(
    var.instance.ami,
    var.ami.id,
    one(data.aws_ami.this[*].id),
  ), null)
}
