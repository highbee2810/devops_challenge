#!/usr/bin/env bash
# One-time: creates the S3 state bucket and writes infrastructure/envs/prod/backend.hcl
set -euo pipefail
REGION="${1:-eu-west-1}"
cd "$(dirname "$0")/../infrastructure/bootstrap"
terraform init -input=false
terraform apply -input=false -auto-approve -var "region=${REGION}"
BUCKET=$(terraform output -raw state_bucket)
cat > ../envs/prod/backend.hcl <<HCL
bucket       = "${BUCKET}"
key          = "devops-challenge/prod/terraform.tfstate"
region       = "${REGION}"
encrypt      = true
use_lockfile = true
HCL
echo "Wrote infrastructure/envs/prod/backend.hcl (bucket: ${BUCKET})"
