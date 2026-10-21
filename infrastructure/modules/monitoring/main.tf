# ---------- Notifications ----------
resource "aws_sns_topic" "alarms" {
  name = "${var.name}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

locals {
  alarm_actions = [aws_sns_topic.alarms.arn]
  alb_dims = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
  svc_dims = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }
}

# ---------- Application alarms ----------
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name}-alb-target-5xx"
  alarm_description   = "Application is returning 5xx responses"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.name}-unhealthy-targets"
  alarm_description   = "One or more targets are failing ALB health checks"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = local.alb_dims
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "running_tasks" {
  alarm_name          = "${var.name}-running-tasks-low"
  alarm_description   = "Fewer ECS tasks are running than the desired minimum"
  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"
  dimensions          = local.svc_dims
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  threshold           = var.min_tasks
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.name}-cpu-high"
  alarm_description   = "Service CPU above 85%"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = local.svc_dims
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.name}-memory-high"
  alarm_description   = "Service memory above 85%"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  dimensions          = local.svc_dims
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# ---------- Log-based metric: application errors ----------
# The app writes JSON logs, so we can filter on the `level` field directly.
resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "${var.name}-app-errors"
  log_group_name = var.app_log_group_name
  pattern        = "{ $.level = \"error\" }"

  metric_transformation {
    name          = "ApplicationErrors"
    namespace     = "${var.name}/App"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "app_errors" {
  alarm_name          = "${var.name}-app-errors"
  alarm_description   = "Application logged 5+ errors in 5 minutes"
  namespace           = "${var.name}/App"
  metric_name         = "ApplicationErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  depends_on          = [aws_cloudwatch_log_metric_filter.app_errors]
}

# ---------- Jenkins host ----------
resource "aws_cloudwatch_metric_alarm" "jenkins_status" {
  alarm_name          = "${var.name}-jenkins-status-check-failed"
  alarm_description   = "Jenkins EC2 instance failed a status check"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  dimensions          = { InstanceId = var.jenkins_instance_id }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
}

# ---------- Dashboard ----------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = var.name
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "ALB requests & 5xx"
          region = var.region
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "ALB target response time (p95)"
          region = var.region
          view   = "timeSeries"
          stat   = "p95"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "ECS CPU & memory (%)"
          region = var.region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.service_name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.cluster_name, "ServiceName", var.service_name]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "Running tasks / healthy targets"
          region = var.region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.cluster_name, "ServiceName", var.service_name, { stat = "Average" }],
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Minimum" }]
          ]
        }
      },
      {
        type = "log", x = 0, y = 12, width = 24, height = 6
        properties = {
          title  = "Recent application errors"
          region = var.region
          view   = "table"
          query  = "SOURCE '${var.app_log_group_name}' | fields @timestamp, message, error | filter level = 'error' | sort @timestamp desc | limit 20"
        }
      }
    ]
  })
}
