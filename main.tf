terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = "tf-state-svm-098824476485"
    key            = "secrets-vending-machine/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# -------------------------------------------------------
# IAM Roles
# -------------------------------------------------------
module "iam_roles" {
  source = "./modules/iam_roles"

  project_name = var.project_name
  environment  = var.environment
  s3_bucket_arn = module.s3_target.bucket_arn
}

# -------------------------------------------------------
# S3 Target Bucket (what credentials grant access to)
# -------------------------------------------------------
module "s3_target" {
  source = "./modules/s3_target"

  project_name = var.project_name
  environment  = var.environment
}

# -------------------------------------------------------
# CloudWatch Log Group
# -------------------------------------------------------
module "cloudwatch" {
  source = "./modules/cloudwatch"

  project_name    = var.project_name
  environment     = var.environment
  log_retention   = var.log_retention_days
}

# -------------------------------------------------------
# Lambda Vending Machine
# -------------------------------------------------------
module "lambda_vending" {
  source = "./modules/lambda_vending"

  project_name        = var.project_name
  environment         = var.environment
  lambda_role_arn     = module.iam_roles.lambda_execution_role_arn
  vended_role_arn     = module.iam_roles.vended_role_arn
  s3_bucket_name      = module.s3_target.bucket_name
  log_group_name      = module.cloudwatch.log_group_name
  credential_ttl_secs = var.credential_ttl_secs
}

# -------------------------------------------------------
# API Gateway
# -------------------------------------------------------
module "api_gateway" {
  source = "./modules/api_gateway"

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  lambda_invoke_arn  = module.lambda_vending.lambda_invoke_arn
  lambda_arn         = module.lambda_vending.lambda_arn
  caller_role_arn    = module.iam_roles.caller_role_arn
}
