#!/bin/bash
# bootstrap.sh
# Run this ONCE before your first terraform init to create remote state infrastructure.
# Usage: ./bootstrap.sh <aws-account-id> <region>

ACCOUNT_ID=${1:?Usage: ./bootstrap.sh <aws-account-id> <region>}
REGION=${2:-us-east-1}
BUCKET_NAME="tf-state-svm-${ACCOUNT_ID}"
TABLE_NAME="tf-lock-svm"

echo "Creating S3 state bucket: $BUCKET_NAME"
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION"

aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "Creating DynamoDB lock table: $TABLE_NAME"
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

echo ""
echo "Bootstrap complete. Update main.tf backend block with:"
echo "  bucket = \"$BUCKET_NAME\""
echo "  region = \"$REGION\""
echo ""
echo "Then run: terraform init"
