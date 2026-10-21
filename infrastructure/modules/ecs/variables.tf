variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "ecr_repository_url" {
  type = string
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory (MiB)"
  type        = number
  default     = 512
}

variable "min_capacity" {
  type    = number
  default = 2
}

variable "max_capacity" {
  type    = number
  default = 6
}

variable "cpu_target_percent" {
  type    = number
  default = 60
}

variable "memory_target_percent" {
  type    = number
  default = 75
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "environment" {
  description = "Extra, non-secret environment variables for the container"
  type        = map(string)
  default     = {}
}
