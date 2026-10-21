variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "certificate_arn" {
  description = "ACM certificate ARN. If set, HTTPS is enabled and HTTP redirects to HTTPS."
  type        = string
  default     = ""
}

variable "ingress_cidrs" {
  description = "CIDRs allowed to reach the load balancer"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_deletion_protection" {
  type    = bool
  default = true
}
