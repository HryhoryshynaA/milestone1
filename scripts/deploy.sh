#!/usr/bin/env bash
# Usage: ./scripts/deploy.sh [network|iam]      (default: network)
#   EnableNatGateway=true ./scripts/deploy.sh   -> adds a NAT gateway (costs money)
#   TRUSTED_ACCOUNT_ID=<12 digits> ./scripts/deploy.sh iam   -> EXPECTED to fail in the sandbox (keep the error!)
set -euo pipefail
export AWS_DEFAULT_REGION="${REGION:-us-east-1}"      # Learner Lab: only us-east-1 / us-west-2
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "acting as: $(aws sts get-caller-identity --query Arn --output text)  region: $AWS_DEFAULT_REGION"
ROLE=(); [[ -n "${CFN_ROLE_ARN:-}" ]] && ROLE=(--role-arn "$CFN_ROLE_ARN")   # optional: act as LabRole
case "${1:-network}" in
  network)
    aws cloudformation deploy --stack-name kv-network-static \
      --template-file "$ROOT/infra/cfn/network-static.yaml" \
      --parameter-overrides EnableNatGateway="${EnableNatGateway:-false}" \
      --no-fail-on-empty-changeset ${ROLE[@]+"${ROLE[@]}"} ;;
  iam)
    : "${TRUSTED_ACCOUNT_ID:?set TRUSTED_ACCOUNT_ID=<12 digits>}"
    aws cloudformation deploy --stack-name kv-iam-readonly \
      --template-file "$ROOT/infra/cfn/iam-readonly.yaml" \
      --parameter-overrides TrustedAccountId="$TRUSTED_ACCOUNT_ID" \
      --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset ${ROLE[@]+"${ROLE[@]}"} ;;
  *) echo "usage: $0 [network|iam]"; exit 2 ;;
esac
