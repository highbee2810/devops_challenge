variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "alarm_email" {
  description = "E-mail address subscribed to alarm notifications (leave empty to skip the subscription)"
  type        = string
  default     = ""
}

variable "alb_arn_suffix" {
  type = string
}

variable "target_group_arn_suffix" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "app_log_group_name" {
  type = string
}

variable "min_tasks" {
  description = "Alarm if fewer tasks than this are running"
  type        = number
  default     = 2
}

variable "jenkins_instance_id" {
  type = string
}
