"""
Secrets Vending Machine - Lambda Handler

Accepts a request specifying an S3 prefix, validates it,
then vends scoped STS credentials via AssumeRole with an
inline session policy that restricts access to that prefix only.

Request body (JSON):
  {
    "prefix": "team-a",
    "requester_id": "svc-account-xyz"   # for audit logging
  }

Response (JSON):
  {
    "access_key_id": "...",
    "secret_access_key": "...",
    "session_token": "...",
    "expiration": "...",
    "scoped_prefix": "team-a",
    "bucket": "...",
    "ttl_seconds": 900
  }
"""

import json
import os
import boto3
import logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sts = boto3.client("sts")

VENDED_ROLE_ARN   = os.environ["VENDED_ROLE_ARN"]
S3_BUCKET_NAME    = os.environ["S3_BUCKET_NAME"]
CREDENTIAL_TTL    = int(os.environ.get("CREDENTIAL_TTL_SECS", "900"))
ALLOWED_PREFIXES  = os.environ.get("ALLOWED_PREFIXES", "team-a,team-b").split(",")


def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))
        prefix       = body.get("prefix", "").strip()
        requester_id = body.get("requester_id", "unknown").strip()

        # --- Validate prefix ---
        if not prefix:
            return error_response(400, "Missing required field: prefix")

        if prefix not in ALLOWED_PREFIXES:
            logger.warning(json.dumps({
                "event": "INVALID_PREFIX_REQUESTED",
                "requester_id": requester_id,
                "requested_prefix": prefix,
                "allowed_prefixes": ALLOWED_PREFIXES,
                "timestamp": utc_now()
            }))
            return error_response(403, f"Prefix '{prefix}' is not permitted.")

        # --- Build scoped session policy (least privilege) ---
        session_policy = json.dumps({
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": "ScopedS3Read",
                    "Effect": "Allow",
                    "Action": ["s3:GetObject"],
                    "Resource": f"arn:aws:s3:::{S3_BUCKET_NAME}/{prefix}/*"
                },
                {
                    "Sid": "ScopedS3List",
                    "Effect": "Allow",
                    "Action": ["s3:ListBucket"],
                    "Resource": f"arn:aws:s3:::{S3_BUCKET_NAME}",
                    "Condition": {
                        "StringLike": {
                            "s3:prefix": [f"{prefix}/*"]
                        }
                    }
                }
            ]
        })

        # --- Assume vended role with scoped session policy ---
        session_name = f"svm-{requester_id}-{prefix}"[:64]  # STS session name max 64 chars

        response = sts.assume_role(
            RoleArn         = VENDED_ROLE_ARN,
            RoleSessionName = session_name,
            Policy          = session_policy,
            DurationSeconds = CREDENTIAL_TTL
        )

        creds = response["Credentials"]

        # --- Audit log ---
        logger.info(json.dumps({
            "event":         "CREDENTIALS_VENDED",
            "requester_id":  requester_id,
            "scoped_prefix": prefix,
            "session_name":  session_name,
            "expiration":    creds["Expiration"].isoformat(),
            "ttl_seconds":   CREDENTIAL_TTL,
            "timestamp":     utc_now()
        }))

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "access_key_id":     creds["AccessKeyId"],
                "secret_access_key": creds["SecretAccessKey"],
                "session_token":     creds["SessionToken"],
                "expiration":        creds["Expiration"].isoformat(),
                "scoped_prefix":     prefix,
                "bucket":            S3_BUCKET_NAME,
                "ttl_seconds":       CREDENTIAL_TTL
            })
        }

    except Exception as e:
        logger.error(json.dumps({
            "event":     "VENDING_ERROR",
            "error":     str(e),
            "timestamp": utc_now()
        }))
        return error_response(500, "Internal error during credential vending.")


def error_response(status_code, message):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"error": message})
    }


def utc_now():
    return datetime.now(timezone.utc).isoformat()
