resource "aws_cloudwatch_log_group" "pyroscope" {
  name              = "/${local.name}/pyroscope"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/${local.name}/nginx"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "system" {
  name              = "/${local.name}/system"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_sns_topic" "alarms" {
  name = "${local.name}-alarms"
  tags = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Host failure: EC2 recovers the instance onto new hardware (same ID, IPs and volumes).
resource "aws_cloudwatch_metric_alarm" "system_status" {
  alarm_name          = "${local.name}-system-status"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  dimensions          = { InstanceId = aws_instance.server.id }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = ["arn:aws:automate:${var.region}:ec2:recover", aws_sns_topic.alarms.arn]
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "instance_status" {
  alarm_name          = "${local.name}-instance-status"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_Instance"
  dimensions          = { InstanceId = aws_instance.server.id }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = ["arn:aws:automate:${var.region}:ec2:reboot", aws_sns_topic.alarms.arn]
  tags                = local.tags
}

# Disk and memory from the CloudWatch agent (namespace CWAgent, dimensions set in the user-data).
resource "aws_cloudwatch_metric_alarm" "disk" {
  for_each            = { root = "/", metastore = "/data" }
  alarm_name          = "${local.name}-disk-${each.key}"
  namespace           = "CWAgent"
  metric_name         = "disk_used_percent"
  dimensions          = { InstanceId = aws_instance.server.id, path = each.value }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "memory" {
  alarm_name          = "${local.name}-memory"
  namespace           = "CWAgent"
  metric_name         = "mem_used_percent"
  dimensions          = { InstanceId = aws_instance.server.id }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 90
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}

# From the watchdog in the user-data, every minute. Ready: Pyroscope ready and nginx serving (missing data
# alarms too: the box or the watchdog is down). Separate from the certificate, so the alarm isn't already
# firing (and silent) while DNS and the first certificate don't exist yet.
resource "aws_cloudwatch_metric_alarm" "ready" {
  alarm_name          = "${local.name}-ready"
  namespace           = "UltraPyroscope"
  metric_name         = "Ready"
  dimensions          = { InstanceId = aws_instance.server.id }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}

# Let's Encrypt certificates last 90 days and certbot renews at 30 left: under 14 means renewal is failing
# (0 until the first certificate exists, i.e. until the A record is created).
resource "aws_cloudwatch_metric_alarm" "certificate" {
  alarm_name          = "${local.name}-certificate-days-left"
  namespace           = "UltraPyroscope"
  metric_name         = "CertDaysLeft"
  dimensions          = { InstanceId = aws_instance.server.id }
  statistic           = "Minimum"
  period              = 3600
  evaluation_periods  = 1
  threshold           = 14
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}

# Samples Pyroscope dropped (rate limits, size and sample caps, too old), summed over all reasons and
# tenants: the watchdog publishes the increase per minute from pyroscope_discarded_samples_total.
resource "aws_cloudwatch_metric_alarm" "discarded" {
  alarm_name          = "${local.name}-discarded-samples"
  namespace           = "UltraPyroscope"
  metric_name         = "DiscardedSamples"
  dimensions          = { InstanceId = aws_instance.server.id }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}
