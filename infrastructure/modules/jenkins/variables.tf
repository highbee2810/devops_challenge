variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "subnet_id" {
  description = "Private subnet for the Jenkins host"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "root_volume_gb" {
  type    = number
  default = 40
}

variable "repo_url" {
  description = "HTTPS URL of the Git repository that contains the Jenkinsfile"
  type        = string
}

variable "ecr_repository_url" {
  type = string
}

variable "ecr_repository_arn" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "ecs_service_arn" {
  type = string
}

variable "ecs_role_arns" {
  description = "Task and execution role ARNs Jenkins may pass when registering task definitions"
  type        = list(string)
}

variable "app_url" {
  description = "Public URL of the app, used by the pipeline smoke test"
  type        = string
}

variable "secret_recovery_window_days" {
  description = "0 = delete the admin secret immediately on destroy"
  type        = number
  default     = 7
}

variable "min_tasks" {
  type    = number
  default = 2
}

variable "log_retention_days" {
  type    = number
  default = 30
}
