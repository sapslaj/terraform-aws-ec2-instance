# terraform-aws-ec2-instance

Creates a standalone EC2 instance and provisions it.

> [!WARNING]
> This module was made for my own use. The API might change at any time, without any warning. Use at your own discretion.

## Usage

```terraform
module "ec2_instance" {
  source = "git@github.com:sapslaj/terraform-aws-ec2-instance.git"

  name = "blahaj"

  instance = {
    instance_type = "t3a.medium"

    # ignore changes to the AMI ID
    lifecyle_ignore = [
      "ami",
    ]
  }
}
```

## Features

- Automatic AMI retrieval (only supports Ubuntu for now)
- Ansible-based provisioning
  - Supports S3 + user data or via Terraform provisioner
- Self-healing Cloudwatch metric alarm actions
- Route53 record creation
  - supports `A` or `CNAME`
  - supports looking up the hosted zone by name
- Elastic IP management
- Default security group creation
  - with default internet access egress rule (configurable)
- IAM role and instance profile creation
  - Auto-attaches `AmazonSSMManagedInstanceCore` for SSM management (configurable)
- Automatic key-pair generation (configurable)
  - can generate both the private and public keys as well as loading the public key into AWS
  - can only generate the public key from a given private key and load that into AWS
  - can load a given public key into AWS
  - can use an existing AWS key pair
  - can use no key pair at all
- Supports ignoring any arbitrary field on the instance (for example, ignoring AMI updates to prevent replacement for long-running instances)
- Supports passing in an existing instance ID and enabling only supporting resources
