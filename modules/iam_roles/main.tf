locals {
  prefix = "${var.project_name}-${var.environment}"
}

# -------------------------------------------------------
# Lambda Execution Role
# -------------------------------------------------------
resource "aws_iam_role" "lambda_execution" {
  name = "${local.prefix}-lambda-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "lambda_execution" {
  name = "${local.prefix}-lambda-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/svm/*"
      },
      {
        Sid    = "AssumeVendedRole"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = aws_iam_role.vended.arn
      }
    ]
  })
}

# -------------------------------------------------------
# Vended Role (what callers actually get scoped access as)
# -------------------------------------------------------
resource "aws_iam_role" "vended" {
  name = "${local.prefix}-vended-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = aws_iam_role.lambda_execution.arn }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "vended" {
  name = "${local.prefix}-vended-policy"
  role = aws_iam_role.vended.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadScopedToPrefix"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
        # Scope enforced at runtime via session policy in Lambda
      }
    ]
  })
}

# -------------------------------------------------------
# Caller Role (what API consumers assume to call the API)
# -------------------------------------------------------
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "caller" {
  name = "${local.prefix}-caller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "caller" {
  name = "${local.prefix}-caller-policy"
  role = aws_iam_role.caller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "InvokeVendingAPI"
      Effect = "Allow"
      Action = "execute-api:Invoke"
      Resource = "arn:aws:execute-api:*:${data.aws_caller_identity.current.account_id}:*"
    }]
  })
}

locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
