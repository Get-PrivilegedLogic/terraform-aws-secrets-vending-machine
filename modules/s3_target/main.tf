locals {
  prefix = "${var.project_name}-${var.environment}"
}

resource "aws_s3_bucket" "target" {
  bucket        = "${local.prefix}-vended-data"
  force_destroy = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "target" {
  bucket                  = aws_s3_bucket.target.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "target" {
  bucket = aws_s3_bucket.target.id
  versioning_configuration { status = "Enabled" }
}

# Seed some sample prefixes to demo scoped access
resource "aws_s3_object" "sample_team_a" {
  bucket  = aws_s3_bucket.target.id
  key     = "team-a/sample.txt"
  content = "This is team-a scoped data. Only accessible with a team-a prefixed credential."
}

resource "aws_s3_object" "sample_team_b" {
  bucket  = aws_s3_bucket.target.id
  key     = "team-b/sample.txt"
  content = "This is team-b scoped data. Only accessible with a team-b prefixed credential."
}
