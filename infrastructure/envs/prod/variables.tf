variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "project" {
  type    = string
  default = "devops-challenge"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "repo_url" {
  description = "HTTPS clone URL of the GitHub repo Jenkins builds from"
  type        = string
}

variable "alarm_email" {
  description = "E-mail for CloudWatch alarm notifications"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "Optional ACM certificate ARN to enable HTTPS on the ALB"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  description = "true = one NAT (cheaper, single-AZ egress); false = one NAT per AZ (production)"
  type        = bool
  default     = false
}

variable "allow_destroy" {
  description = "Set true only for teardown: disables ALB deletion protection, force-deletes ECR images and the Jenkins secret"
  type        = bool
  default     = false
}

variable "min_tasks" {
  type    = number
  default = 2
}

variable "max_tasks" {
  type    = number
  default = 6
}

variable "jenkins_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "alb_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
