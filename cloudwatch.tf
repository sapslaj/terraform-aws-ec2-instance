locals {
  cloudwatch_metric_alarms = var.cloudwatch.metric_alarms
}

resource "aws_cloudwatch_metric_alarm" "instance_status_check" {
  count = contains(local.cloudwatch_metric_alarms, "instance_status_check") ? 1 : 0

  alarm_name          = "${local.instance_id}-status-check-failed-instance"
  evaluation_periods  = 2
  period              = 60
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_Instance"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  statistic           = "Maximum"
  dimensions = {
    InstanceId = local.instance_id
  }
  alarm_actions = [
    "arn:aws:swf:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:action/actions/AWS_EC2.InstanceId.Reboot/1.0"
  ]
  tags = merge({
    Name = "${local.name}-status-check-failed-instance"
  }, local.tags)
}

resource "aws_cloudwatch_metric_alarm" "system_status_check" {
  count = contains(local.cloudwatch_metric_alarms, "system_status_check") ? 1 : 0

  alarm_name          = "${local.instance_id}-status-check-failed-system"
  evaluation_periods  = 2
  period              = 60
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  statistic           = "Maximum"
  dimensions = {
    InstanceId = local.instance_id
  }
  alarm_actions = [
    "arn:aws:automate:${data.aws_region.current.name}:ec2:recover"
  ]
  tags = merge({
    Name = "${local.name}-status-check-failed-system"
  }, local.tags)
}
