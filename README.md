# KV Capstone — serverless key-value store ("light DynamoDB")

Cloud Architectures (SE470) capstone. **Current milestone: M1 — Infrastructure setup.**
Workflow: *spec → ADR → code → demo.* The OpenSpec change was written before any template.

## Map of files
| File | Responsible for |
|---|---|
| `openspec/changes/m1-infrastructure-setup/proposal.md` | WHAT we build and why; requirements + testable scenarios; task checklist (written before code) |
| `docs/adr/0001-iac-tool.md` | WHY CloudFormation (vs Terraform / CDK / scripts / console) |
| `docs/adr/0002-stack-layout.md` | WHY three stacks (network-static, iam-readonly, later app-dynamic) |
| `docs/adr/0003-cidr-scheme.md` | WHY 10.42.0.0/16 and how subnets are numbered |
| `infra/cfn/network-static.yaml` | The network: VPC, 2 public + 2 private subnets, IGW, routes, NACLs, SG, S3 endpoint, optional NAT |
| `infra/cfn/iam-readonly.yaml` | The view-only policy and the assumable role (delivered as code; sandbox refuses it) |
| `scripts/deploy.sh` | Create/update a stack (`network` or `iam`) |
| `scripts/teardown.sh` | Delete the network stack |
| `scripts/verify.sh` | Check the LIVE stack against the spec scenarios |
| `docs/m1/01-labrole-dissection.md` | Tasks 1–3: what LabRole can/can't do and how I found out; the IAM policy/role explained |
| `docs/m1/06-quotas.md` | Task 6: quotas that can limit Milestone 2 |
| `docs/m1/07-budget.md` | Task 7: monthly budget (2 shards) vs credit ceiling |
| `docs/m1/08-recreatability.md` | Task 8: teardown + rebuild timings, what broke |

## Bring it up
Where it runs: the Academy lab terminal is an EC2 instance. Its credentials come **automatically from the
instance profile** (an assumed role; the session name in the ARN is the instance id) — do NOT paste anything into
`~/.aws/credentials` there. Only on your own laptop do you copy the 3 lines from *AWS Details → AWS CLI → Show*.
Credentials rotate automatically and stop working when the 180-minute session ends.
```bash
aws sts get-caller-identity                          # ARN must contain assumed-role/<RoleName>/i-…
export REGION=us-east-1                              # only us-east-1 / us-west-2 work in the Lab
cfn-lint infra/cfn/*.yaml                            # static checks (or: aws cloudformation validate-template)
# CloudFormation uses the caller's assumed role by default. Only if a deploy is denied, try:
#   export CFN_ROLE_ARN=arn:aws:iam::<account-id>:role/<RoleName>
./scripts/deploy.sh network                          # NAT is OFF by default (saves ~$37/month)
EnableNatGateway=true ./scripts/deploy.sh network    # only if private subnets need outbound internet
```

## Verify it
```bash
./scripts/verify.sh   # public→IGW, private has no IGW, 4 subnets, no overlap — all on the live stack
```
IAM stack (task 3, **expected to fail** in the sandbox — keep the error as evidence):
```bash
TRUSTED_ACCOUNT_ID=<12 digits> ./scripts/deploy.sh iam
```

## Tear down (end of every session — also the budget strategy)
```bash
./scripts/teardown.sh
```

## What changed since the previous milestone
First milestone — nothing before it.

## Status
| Task | State |
|---|---|
| 2, 3 IAM policy + role as IaC | written, `cfn-lint` clean; deployment refused by sandbox (fill evidence in `01-…` §6) |
| 4, 5 network stack | written, `cfn-lint` clean; live deploy + `verify.sh` = run in your sandbox |
| 1, 6, 8 | document skeletons ready; **measured values come from your sandbox** (`TODO(you)`) |
| 7 | model + conclusions done; confirm compute prices and your real ceiling |
