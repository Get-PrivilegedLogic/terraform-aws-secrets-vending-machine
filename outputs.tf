output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "s3_target_bucket" {
  description = "Target S3 bucket name callers get access to"
  value       = module.s3_target.bucket_name
}

output "caller_role_arn" {
  description = "IAM role ARN callers must assume to invoke the API"
  value       = module.iam_roles.caller_role_arn
}

output "log_group_name" {
  description = "CloudWatch log group for audit trail"
  value       = module.cloudwatch.log_group_name
}

output "credential_ttl_secs" {
  description = "TTL of vended credentials in seconds"
  value       = var.credential_ttl_secs
}
