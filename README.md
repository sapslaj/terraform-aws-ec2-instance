# terraform-aws-ec2-instance

Creates a standalone EC2 instance and provisions it.

## Usage

```terraform
module "ec2_instance" {
  source = "git@github.com:sapslaj/terraform-aws-ec2-instance.git"

  name = "blahaj"

  instance = {
    instance_type = "t3a.medium"
  }
}
```
