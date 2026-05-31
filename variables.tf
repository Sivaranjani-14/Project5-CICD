variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "The AWS region to deploy all resources into."
}

variable "environment_name" {
  type        = string
  default     = "dev"
  description = "The deployment environment prefix (e.g., dev, qa, prod)."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "The global IP address range for our virtual private network."
}

variable "db_username" {
  type        = string
  default     = "dbadmin"
  description = "The master administrator username for the RDS MySQL instance."
}

variable "db_password" {
  type        = string
  default     = "SafeDevPassword2026!"
  sensitive   = true
  description = "The master password. Marked sensitive so it never prints out in logs."
}