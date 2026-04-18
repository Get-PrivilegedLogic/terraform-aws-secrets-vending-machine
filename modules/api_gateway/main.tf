locals {
  prefix = "${var.project_name}-${var.environment}"
}

resource "aws_api_gateway_rest_api" "svm" {
  name        = "${local.prefix}-svm-api"
  description = "Secrets Vending Machine - issues scoped S3 credentials"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# /vend resource
resource "aws_api_gateway_resource" "vend" {
  rest_api_id = aws_api_gateway_rest_api.svm.id
  parent_id   = aws_api_gateway_rest_api.svm.root_resource_id
  path_part   = "vend"
}

# POST /vend
resource "aws_api_gateway_method" "post_vend" {
  rest_api_id   = aws_api_gateway_rest_api.svm.id
  resource_id   = aws_api_gateway_resource.vend.id
  http_method   = "POST"
  authorization = "AWS_IAM"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.svm.id
  resource_id             = aws_api_gateway_resource.vend.id
  http_method             = aws_api_gateway_method.post_vend.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

resource "aws_api_gateway_method_response" "post_vend_200" {
  rest_api_id = aws_api_gateway_rest_api.svm.id
  resource_id = aws_api_gateway_resource.vend.id
  http_method = aws_api_gateway_method.post_vend.http_method
  status_code = "200"
}

# Deploy
resource "aws_api_gateway_deployment" "svm" {
  depends_on  = [aws_api_gateway_integration.lambda]
  rest_api_id = aws_api_gateway_rest_api.svm.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "svm" {
  rest_api_id   = aws_api_gateway_rest_api.svm.id
  deployment_id = aws_api_gateway_deployment.svm.id
  stage_name    = var.environment

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}
