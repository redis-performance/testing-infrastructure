resource "aws_cloudwatch_log_group" "mimir" {
  name              = "/${local.name}/mimir"
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

# Sustained CPU: the sign the instance is too small for the ingest (README.md, "Sizing").
resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "${local.name}-cpu"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { InstanceId = aws_instance.server.id }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}

# Disk and memory from the CloudWatch agent (namespace CWAgent, dimensions set in the user-data).
resource "aws_cloudwatch_metric_alarm" "disk" {
  for_each            = { root = "/", data = "/data" }
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

# From the watchdog in the user-data, every minute. Ready: Mimir ready and nginx serving (missing data
# alarms too: the box or the watchdog is down). Separate from the certificate, so the alarm isn't already
# firing (and silent) while DNS and the first certificate don't exist yet.
resource "aws_cloudwatch_metric_alarm" "ready" {
  alarm_name          = "${local.name}-ready"
  namespace           = "PerfMimir"
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
  namespace           = "PerfMimir"
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

# Samples Mimir dropped (per-tenant series and rate limits, too old or out of the out-of-order window,
# invalid labels), summed over all reasons and tenants: the watchdog publishes the increase per minute from
# cortex_discarded_samples_total. The logs say which tenant and why.
resource "aws_cloudwatch_metric_alarm" "discarded" {
  alarm_name          = "${local.name}-discarded-samples"
  namespace           = "PerfMimir"
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

# Active series across all tenants as a percentage of max_series_total: past 100 the ingester refuses new
# series for everyone. 80 leaves time to raise the limit (and the instance) or find the cardinality leak.
resource "aws_cloudwatch_metric_alarm" "series" {
  alarm_name          = "${local.name}-series-used"
  namespace           = "PerfMimir"
  metric_name         = "SeriesUsedPercent"
  dimensions          = { InstanceId = aws_instance.server.id }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}

# A credential line dropped (malformed, or its tenant isn't in `tenants`), or tenant overrides not in force
# (refused by the check or by Mimir). /var/log/perf-mimir-ops.log says which.
resource "aws_cloudwatch_metric_alarm" "config_rejected" {
  alarm_name          = "${local.name}-config-rejected"
  namespace           = "PerfMimir"
  metric_name         = "ConfigRejected"
  dimensions          = { InstanceId = aws_instance.server.id }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}

# The data volume isn't snapshotted because S3 has every shipped block: these two say when that stops being
# true. Block uploads failing in two 15-minute windows in a row (one-off S3 errors are retried)...
resource "aws_cloudwatch_metric_alarm" "shipper" {
  alarm_name          = "${local.name}-block-upload-failures"
  namespace           = "PerfMimir"
  metric_name         = "ShipperFailures"
  dimensions          = { InstanceId = aws_instance.server.id }
  statistic           = "Sum"
  period              = 900
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}

# ... and the compactor (hourly) not having finished a run for 6 hours.
resource "aws_cloudwatch_metric_alarm" "compactor" {
  alarm_name          = "${local.name}-compactor-stale"
  namespace           = "PerfMimir"
  metric_name         = "CompactorHoursSinceSuccess"
  dimensions          = { InstanceId = aws_instance.server.id }
  statistic           = "Maximum"
  period              = 900
  evaluation_periods  = 2
  threshold           = 6
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}
