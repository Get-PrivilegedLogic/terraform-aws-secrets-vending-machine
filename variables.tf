variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "svm"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "credential_ttl_secs" {
  description = "TTL in seconds for vended STS credentials (max 3600)"
  type        = number
  default     = 900 # 15 minutes - matches CyberArk PSM session defaults
}
