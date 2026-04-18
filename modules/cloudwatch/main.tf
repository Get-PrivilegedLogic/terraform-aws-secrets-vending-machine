resource "aws_cloudwatch_log_group" "svm" {
  name              = "/svm/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
