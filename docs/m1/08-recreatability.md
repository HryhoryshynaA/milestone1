# Task 8 — Proof of recreatability

Procedure (time each phase, e.g. with `time`):
```bash
time ./scripts/teardown.sh          # 1. delete the whole stack
time ./scripts/deploy.sh network    # 2. recreate from the template ONLY
./scripts/verify.sh                 # 3. assert the spec scenarios on the live stack
aws cloudformation describe-stack-events --stack-name kv-network-static \
  --query "StackEvents[?contains(ResourceStatus,'FAILED')].[Timestamp,LogicalResourceId,ResourceStatusReason]" --output text
```

**First, do the experiment *badly on purpose*:** run it once cold with nothing prepared. The rubric asks
what broke on the *first* attempt — record that honestly, then fix and re-run.

## Results `TODO(you)`
| Attempt | Delete (s) | Create (s) | Verify | Total (s) | Notes |
|---|---:|---:|---|---:|---|
| 1 (cold) | | | | | |
| 2 (after fix) | | | | | |
| 3 (with `EnableNatGateway=true`, optional) | | | | | NAT adds creation/deletion time |

## What broke on the first attempt `TODO(you)`
Paste the FAILED events block, then fill:
- Symptom:
- Root cause:
- Fix (commit hash):
- How the spec/ADR changed because of it:

## Watch-list — *predictions, not results* (delete the ones that did not happen to you)
- Wrong region (only us-east-1 / us-west-2 work) → AccessDenied on every call.
- Expired Learner Lab credentials mid-run (session timer) → `ExpiredToken`.
- `AWS::EC2::Subnet` AZ selection: `Fn::GetAZs` order differs per account; fine here because I select by index, but an AZ without capacity can fail.
- EIP / NAT: EIP quota, or NAT still `deleting` when the VPC delete starts → `DELETE_FAILED` with "dependency violation" (rerun delete).
- Leftover resources created by hand in the VPC (ENIs, extra SGs) block stack delete — the reason the rule is "never click in a stack-owned VPC".
- `--role-arn` needed so CloudFormation acts through LabRole.

## Why it is *actually* recreatable (explain, don't just show timings)
- Declarative template; no manual step between delete and create (the script is the only entry point).
- No retained/stateful resources in the stack (no buckets, no data) → idempotent under delete/create (the lecture's warning: not every resource is idempotent — buckets are the classic one).
- All names and addresses derive from parameters (`ProjectName`, `EnvironmentName`, `VpcCidr` → `Fn::Cidr`).
- Verification is **executable**, asserted against the live stack, not eyeballed.
