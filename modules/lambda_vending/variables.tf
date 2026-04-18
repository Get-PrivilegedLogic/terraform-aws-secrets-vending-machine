variable "project_name"        { type = string }
variable "environment"          { type = string }
variable "lambda_role_arn"      { type = string }
variable "vended_role_arn"      { type = string }
variable "s3_bucket_name"       { type = string }
variable "log_group_name"       { type = string }
variable "credential_ttl_secs"  { type = number }
