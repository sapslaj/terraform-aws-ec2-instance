data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  name = var.name
  tags = var.tags
}
