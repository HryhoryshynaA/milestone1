# Task 1 (+2, +3) — Dissecting the sandbox role (LabRole)

> Rule for the defense: for every claim write **what** it is and **how I found out**.
> Sections marked `TODO(you)` must be filled from *your* sandbox run. Paste real command output (or a screenshot) here.

## 1. How I found out — four independent methods
| # | Method | What it proves | Command / place |
|---|---|---|---|
| A | CLI identity | which principal I am (`assumed-role/LabRole/...`) | `aws sts get-caller-identity` |
| B | Read the role's policies | what is *written* (attached + inline JSON) | `aws iam get-role --role-name $ROLE`, `aws iam list-attached-role-policies --role-name $ROLE`, `aws iam get-policy-version …` — may itself be denied: that is a finding |
| C | **Policy Simulator** (console or `simulate-principal-policy`) | what the *evaluation engine decides*: `allowed` / `implicitDeny` / `explicitDeny` per action | https://policysim.aws.amazon.com (pick LabRole, tick `iam:CreateRole`, `iam:CreatePolicy`, `ec2:CreateVpc` …) or `aws iam simulate-principal-policy --policy-source-arn <LabRole ARN> --action-names iam:CreateRole iam:CreatePolicy ec2:CreateVpc` |
| D | Negative probe | what really happens when I try; the error text tells **why** | `aws iam create-policy --policy-name kv-probe --policy-document file://p.json` (delete it if it unexpectedly succeeds) |
| E | Deploy the real IaC | that CloudFormation hits the same wall | `TRUSTED_ACCOUNT_ID=<id> ./scripts/deploy.sh iam`, then `aws cloudformation describe-stack-events --stack-name kv-iam-readonly` |

Why more than one: reading policy JSON (B) shows intent but not the final decision — Service Control
Policies, permission boundaries and session policies can sit *above* it and are invisible to B. C and D
see the outcome. (Evaluation model, as corrected after lecture: an explicit Deny always wins;
identity-policy and resource-policy allows combine as a union; SCPs / permission boundaries / session
policies are **ceilings** — an intersection.)

AccessDenied wording is evidence:
| Message says | Meaning |
|---|---|
| "…because **no identity-based policy allows** the iam:CreateRole action" | **implicit** deny — nobody granted it |
| "…with an **explicit deny** in an identity-based policy / service control policy" | **explicit** deny — someone forbade it; cannot be overridden by any allow |

## 2. What it is
Observed in my sandbox terminal (`aws sts get-caller-identity`):
- `UserId = AROA…:i-0429d82e889a71dc7` → an **assumed role** (`AROA` prefix), and the part after the colon is an
  **EC2 instance id**. So the lab terminal is an EC2 instance and its credentials come from the **instance profile**
  (served by the instance metadata service, rotated automatically) — not from an IAM user or pasted keys.
- Prompt IP `172.31.x.x` → the instance sits in the account's **default VPC (172.31.0.0/16)**, which is why ADR-0003 avoids that range.
- `TODO(you)` Full ARN and role name: `aws sts get-caller-identity --query Arn --output text` (expected `…assumed-role/LabRole/i-…`).
- `TODO(you)` Trust policy (`aws iam get-role --role-name $ROLE` → `AssumeRolePolicyDocument`): who may assume it? (expect ec2.amazonaws.com and other services)
- Optional comparison: the credentials from *AWS Details → AWS CLI* belong to a *different* principal (commonly `voclabs`).
  Run `get-caller-identity` with them on your laptop and note both — two principals, two permission sets.
Services such as CloudFormation, Lambda, EC2 may be allowed to assume LabRole, which is how you give services an
identity without creating roles yourself.

## 3. What it allows / denies
**Documented by AWS Academy** (public Learner Lab service notes — treat as *hypotheses to confirm*, not as my findings):
- Only **us-east-1** and **us-west-2** are usable.
- IAM is "extremely limited": cannot create users or groups; cannot create roles except service-linked roles.
- Many services (EC2, Lambda, CloudFormation, …) can assume LabRole; EC2 key pair `vockey` and instance profile `LabInstanceProfile` are provided.
- EC2 has a vCPU cap (documented as 32 concurrent vCPUs; 9 concurrent instances in us-east-1).

**Measured by me** (`TODO(you)` — fill from method C/D output):
| Action | Decision | Method | Error wording (implicit/explicit) |
|---|---|---|---|
| iam:CreatePolicy | | | |
| iam:CreateRole | | | |
| iam:AttachRolePolicy | | | |
| iam:PassRole (LabRole to a service) | | | |
| ec2:CreateVpc / CreateSubnet / CreateInternetGateway | | | |
| ec2:CreateNatGateway / AllocateAddress | | | |
| ec2:CreateVpcEndpoint | | | |
| cloudformation:CreateStack | | | |
| servicequotas:ListServiceQuotas | | | |

## 4. Task 2 — the view-only policy (IaC: `infra/cfn/iam-readonly.yaml`, `ReadOnlyPolicy`)
What it would do once attached:
- **Allow** only `Describe*`, `List*`, selected `Get*` metadata calls (EC2/ELB/CloudFormation/CloudWatch/Logs/Lambda config/DynamoDB table metadata/S3 bucket metadata/IAM read/Service Quotas). No `Create*`, `Put*`, `Update*`, `Delete*`, `Run*`, `Attach*`.
- **Why not `Get*` everywhere or AWS's `ReadOnlyAccess`:** many `Get*`/`Describe*` calls *read data or secrets* — `secretsmanager:GetSecretValue`, `ssm:GetParameter` (decrypted), `s3:GetObject`, `dynamodb:GetItem/Scan`, `ec2:DescribeInstanceAttribute` (returns user-data). "View resources" ≠ "read the data inside them".
- **Explicit Deny** on exactly those, so even if the principal later receives a broader allow from another policy, the deny still wins.
- `Resource: "*"` is deliberate: Describe/List actions mostly cannot be resource-scoped.

## 5. Task 3 — the assumable role (`ReadOnlyRole`)
- **Trust policy**: principals of account `TrustedAccountId` may `sts:AssumeRole`, **only with MFA** (`aws:MultiFactorAuthPresent=true`) by default; 1-hour max session.
- **Two-sided trust**: the role's trust policy lets the principal in, but the principal's *own* identity policy must also allow `sts:AssumeRole` on this role. Missing either side → AccessDenied.
- A role is not a permanent identity: you *take it on temporarily* and get short-lived credentials ("a role is something we take on for a period of time").

## 6. Why the sandbox refuses tasks 2–3
Hypothesis (to confirm with methods C/D/E): LabRole holds no `iam:CreatePolicy`/`iam:CreateRole`, and Academy additionally blocks them — so creating `AWS::IAM::ManagedPolicy` / `AWS::IAM::Role` fails with AccessDenied during CREATE and the stack rolls back (which is why the IAM template is a **separate stack**, ADR-0002).
- `TODO(you)` Paste the CloudFormation event reason from `./scripts/deploy.sh iam`.
- `TODO(you)` State whether it was implicit or explicit deny (wording table above).
- What still works: `cfn-lint` and `aws cloudformation validate-template` pass because they check syntax, not permissions — so the artifact is verified even though it is not deployable here.
