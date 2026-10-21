variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to span (2 or 3 recommended)"
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway (cheaper, not AZ-resilient) instead of one per AZ"
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "Retention for VPC flow logs"
  type        = number
  default     = 30
}
