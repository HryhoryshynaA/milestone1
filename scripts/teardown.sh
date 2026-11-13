#!/usr/bin/env bash
# Deletes the network stack and waits. Run at the end of every session (also the budget strategy).
set -euo pipefail
export AWS_DEFAULT_REGION="${REGION:-us-east-1}"
echo "acting as: $(aws sts get-caller-identity --query Arn --output text)  region: $AWS_DEFAULT_REGION"
ROLE=(); [[ -n "${CFN_ROLE_ARN:-}" ]] && ROLE=(--role-arn "$CFN_ROLE_ARN")
aws cloudformation delete-stack --stack-name kv-network-static ${ROLE[@]+"${ROLE[@]}"}
aws cloudformation wait stack-delete-complete --stack-name kv-network-static
echo "deleted kv-network-static"
