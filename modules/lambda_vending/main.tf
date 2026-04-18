locals {
  prefix = "${var.project_name}-${var.environment}"
}

# Package the Lambda zip from source
data "archive_file" "vending_machine" {
  type        = "zip"
  source_dir  = "${path.root}/lambda/vending_machine"
  output_path = "${path.module}/vending_machine.zip"
}

resource "aws_lambda_function" "vending_machine" {
  function_name    = "${local.prefix}-vending-machine"
  role             = var.lambda_role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.vending_machine.output_path
  source_code_hash = data.archive_file.vending_machine.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      VENDED_ROLE_ARN     = var.vended_role_arn
      S3_BUCKET_NAME      = var.s3_bucket_name
      CREDENTIAL_TTL_SECS = tostring(var.credential_ttl_secs)
      ALLOWED_PREFIXES    = "team-a,team-b"
    }
  }

  logging_config {
    log_format = "JSON"
    log_group  = var.log_group_name
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.vending_machine.function_name
  principal     = "apigateway.amazonaws.com"
}
