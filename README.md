# Secrets Vending Machine

A cloud-native privileged access solution built on AWS that issues temporary, scoped credentials on demand — no static keys, no standing permissions, full audit trail.

Inspired by enterprise PAM platforms like CyberArk, this project reimplements the core credential brokering concept using AWS-native serverless tooling, deployed entirely as Infrastructure as Code with Terraform.

---

## The Problem It Solves

Static AWS credentials are one of the most common causes of cloud security incidents. Developers and services often hold long-lived access keys with broad permissions — keys that can be stolen, leaked, or abused long after they were issued.

The Secrets Vending Machine eliminates static credentials by acting as a broker: callers request temporary access to a specific resource scope, the system validates the request, and issues short-lived credentials (15 minutes by default) that are cryptographically scoped to only what was requested. When the TTL expires, the credentials are dead.

---

## How It Works

```
Caller → assumes IAM Role → calls POST /vend (SigV4 signed)
       → API Gateway (IAM Auth) → Lambda validates request
       → STS AssumeRole with inline session policy
       → Scoped credentials returned (15 min TTL)
       → Caller accesses only their permitted S3 prefix
       → Audit log written to CloudWatch
```

**Key security properties:**
- No static credentials ever issued or stored
- Session policy enforces least privilege at runtime, not just at role level
- Every vend request is logged with requester ID, scope, session name, and expiration
- API requires IAM authentication — unauthenticated calls are rejected at the gateway

---

## Architecture

| Component | Purpose |
|-----------|---------|
| **API Gateway** | REST API with IAM (SigV4) authentication on `POST /vend` |
| **Lambda** | Validates request, builds scoped session policy, calls STS |
| **STS AssumeRole** | Issues temporary credentials scoped to requested prefix |
| **S3** | Target resource — credentials are scoped to a specific prefix only |
| **IAM Roles** | Caller role, Lambda execution role, vended role with least privilege |
| **CloudWatch** | Structured JSON audit log per credential vend |
| **Terraform** | All infrastructure defined and deployed as code |

---

## Project Structure

```
terraform-aws-secrets-vending-machine/
├── main.tf                        # Root module, backend config, provider
├── variables.tf
├── outputs.tf
├── bootstrap.sh                   # One-time remote state setup
├── environments/
│   └── prod/
│       └── prod.tfvars
├── lambda/
│   └── vending_machine/
│       └── handler.py             # Credential broker logic
└── modules/
    ├── api_gateway/               # REST API with IAM auth
    ├── cloudwatch/                # Audit log group
    ├── iam_roles/                 # Caller, Lambda, and vended roles
    ├── lambda_vending/            # Lambda function and packaging
    └── s3_target/                 # Scoped target bucket with sample data
```

---

## What Gets Deployed

- **21 AWS resources** provisioned via Terraform
- Remote state stored in S3 with DynamoDB locking
- All resources tagged with `Project`, `Environment`, and `ManagedBy = terraform`

---

## Setup

### Prerequisites
- Terraform >= 1.6.0
- AWS CLI configured with appropriate permissions

### 1. Bootstrap Remote State (run once)

```bash
chmod +x bootstrap.sh
./bootstrap.sh <your-aws-account-id> us-east-1
```

Update the `backend` block in `main.tf` with the output bucket name.

### 2. Deploy

```bash
terraform init

# First apply — IAM and S3 first to resolve role dependencies
terraform apply -var-file="environments/prod/prod.tfvars" \
  -target=module.iam_roles -target=module.s3_target

# Full apply
terraform apply -var-file="environments/prod/prod.tfvars"
```

---

## Testing End to End

### Step 1 — Assume the caller role

```bash
aws sts assume-role \
  --role-arn "arn:aws:iam::YOUR_ACCOUNT_ID:role/svm-prod-caller-role" \
  --role-session-name "test-session"
```

Export the returned credentials to your shell.

### Step 2 — Request scoped credentials

```bash
py test_vend.py
```

Or inline:

```python
import boto3, json, requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

session = boto3.Session()
creds = session.get_credentials().get_frozen_credentials()
url = "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/vend"
body = json.dumps({"prefix": "team-a", "requester_id": "your-id"})

request = AWSRequest(method="POST", url=url, data=body, headers={"Content-Type": "application/json"})
SigV4Auth(creds, "execute-api", "us-east-1").add_auth(request)
response = requests.post(url, data=body, headers=dict(request.headers))
print(response.json())
```

### Step 3 — Verify scoping

Use the vended credentials to access `team-a/sample.txt` — succeeds.
Attempt to access `team-b/sample.txt` with the same credentials — denied.

```
=== Testing team-a access (should SUCCEED) ===
SUCCESS: This is team-a scoped data. Only accessible with a team-a prefixed credential.

=== Testing team-b access (should DENY) ===
DENIED: User is not authorized to perform: s3:GetObject ... because no session policy allows the s3:GetObject action
```

---

## Audit Log Sample

Every credential vend writes a structured JSON entry to CloudWatch:

```json
{
  "event": "CREDENTIALS_VENDED",
  "requester_id": "brad-test",
  "scoped_prefix": "team-a",
  "session_name": "svm-brad-test-team-a",
  "expiration": "2026-04-18T03:12:49+00:00",
  "ttl_seconds": 900,
  "timestamp": "2026-04-18T02:57:49+00:00"
}
```

---

## Teardown

```bash
terraform destroy -var-file="environments/prod/prod.tfvars"
```

Note: The S3 state bucket and DynamoDB lock table created by `bootstrap.sh` are not managed by Terraform and must be deleted manually in the AWS console if no longer needed.

---

## Connection to Enterprise PAM

This project applies the same principles used in enterprise Privileged Access Management platforms:

| PAM Concept | Implementation Here |
|-------------|-------------------|
| Just-in-time access | 15-minute TTL credentials, no standing permissions |
| Least privilege | Session policy scopes access to a single S3 prefix at runtime |
| Session isolation | Each vend creates a uniquely named STS session |
| Audit trail | Structured log per vend with requester ID and scope |
| Credential brokering | Callers never touch the underlying role directly |
