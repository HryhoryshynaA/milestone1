# ADR-0001: Infrastructure-as-code tool — AWS CloudFormation

- Status: accepted (M1) · Date: 2026-11 · Deciders: me
- Spec: `openspec/changes/m1-infrastructure-setup`

## Context
Everything must be re-creatable from code (task 8) inside the AWS Academy sandbox, where I
cannot make IAM users/roles and my credentials are short-lived session credentials. The course
said that for the labs "either Terraform or CloudFormation" is acceptable (lecture 2026-09-03).
IaC for infrastructure should be **declarative** (describe the outcome; the engine works out the
steps) rather than imperative (bash/CLI scripts), and should be **idempotent** (apply twice ==
apply once) — both points from the IaC lecture.

## Decision drivers
1. Works with the sandbox's short-lived creds / LabRole without extra bootstrap.
2. No state I must store, lock, back up or lose.
3. Debuggability when a create fails.
4. Matches the rest of the course material (CloudFormation was demoed live; Terraform was positioned for "home" use).
5. Learning value for the defense: I must be able to explain every line.

## Options considered
| Option | For | Against |
|---|---|---|
| **CloudFormation (YAML)** ✔ | Native, no extra binary; service holds the state (the *stack*); runs with the session's assumed role (optionally `--role-arn`); **stack event timeline** shows exactly which resource failed and why; change sets for previews; IaC generator for adopting click-ops resources | AWS-only (lock-in); verbose; slower feedback than Terraform on some resources; no `plan`-style graph UI |
| Terraform (HCL) | Cloud-agnostic, great `plan`, big module ecosystem | Needs a state backend (local file = fragile, S3+lock = chicken-and-egg bootstrap in a sandbox that wipes); extra tool install; its multi-cloud strength is worthless here (AWS-only) |
| AWS CDK | Real languages, loops | Needs bootstrap stack (`cdk bootstrap` creates IAM roles + S3 bucket → **blocked by the sandbox**); synth step adds a layer I'd have to defend |
| CLI/bash scripts | Zero dependencies | **Imperative** and not idempotent (second run errors or duplicates); no drift/rollback; exactly the anti-pattern from the lecture |
| Console clicking | Fast first time | Not reproducible; fails task 8 outright |

## Decision
Use **CloudFormation**, YAML, validated with `cfn-lint` + `aws cloudformation validate-template`,
deployed with `aws cloudformation deploy` (create-or-update, no-op on empty change set).

## Consequences
- (+) Rollback on failed create is automatic; failure reason is in stack events.
- (+) `DependsOn`, `Parameters`, `Conditions`, intrinsic functions (`Fn::Cidr`, `Fn::GetAZs`, `Fn::Sub`) used where they earn their keep.
- (−) Not every resource is idempotent under re-apply (S3 buckets, retained resources). **The network stack contains none**, which is why it is safe to delete/recreate; anything of that kind goes into a separately managed stack later (ADR-0002).
- (−) Locked to AWS. Accepted: the capstone *is* an AWS-native design.

## Where this lives in code
`infra/cfn/*.yaml`, `scripts/deploy.sh` (`aws cloudformation deploy`; optional `CFN_ROLE_ARN` makes CloudFormation act as that role).

## Revisit when
We need multi-cloud, or the sandbox starts permitting a Terraform remote-state backend.
