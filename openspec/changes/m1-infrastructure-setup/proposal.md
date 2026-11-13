# Change: M1 — Infrastructure setup

## Why
The capstone (a "light" serverless key-value store, DynamoDB-style) needs a repeatable foundation
before any application code exists. Milestone 2 (sharding, replication, benchmark) deploys *into*
this network, so it must be (a) correct, (b) cheap enough for the Academy credit ceiling, and
(c) rebuildable from code alone — the sandbox session and budget are both disposable.

## What changes
- **Static network stack** `kv-network-static`: VPC, 2 public + 2 private subnets in 2 AZs, Internet
  Gateway, route tables, NACLs, an internal security group, a free S3 gateway endpoint, and an
  *optional* NAT gateway (off by default).
- **IAM stack** `kv-iam-readonly`: view-only managed policy + assumable role. Delivered as IaC and
  **expected to be refused** by the sandbox (ADR-0002).
- Documentation: LabRole dissection, quota review, M2 budget, recreatability proof.
- 3 ADRs: IaC tool, stack layout, CIDR scheme.

## Out of scope
Application compute/storage (M2); flow logs; VPN/peering; NAT per AZ.

## Requirements and scenarios (how each is verified)
### R1 — VPC with public and private tiers
- **WHEN** a public subnet's route table is inspected **THEN** it has `0.0.0.0/0 -> Internet Gateway`.
- **WHEN** a private subnet's route table is inspected (default params) **THEN** it has no IGW route and no `0.0.0.0/0` route.
- **WHEN** deployed with `EnableNatGateway=true` **THEN** private subnets get `0.0.0.0/0 -> NAT` and the NAT sits in a public subnet.

### R2 — Non-overlapping, documented addressing
- **WHEN** the template is read **THEN** subnet CIDRs are computed from `VpcCidr` with `Fn::Cidr`, follow the bands in ADR-0003 and do not overlap.

### R3 — Recreatable from code
- **WHEN** the stack is deleted and deployed again from the template **THEN** `scripts/verify.sh` passes with no manual step.

### R4 — View-only policy
- **WHEN** the policy's Allow statements are listed **THEN** none grants a write action or `*`.
- **WHEN** a principal also holds a broad allow **THEN** the Deny on data/secrets still applies (explicit deny wins).

### R5 — Assumable role, two-sided trust
- **WHEN** a principal assumes the role **THEN** the trust policy allows it (MFA by default) AND the principal's own policy allows `sts:AssumeRole`.

### R6 — Sandbox refusal is documented, not hidden
- **WHEN** `cfn-lint` / `validate-template` run on the IAM template **THEN** both pass even though `create-stack` is refused.

## Tasks (one per milestone task)
- [ ] 1. LabRole dissection → `docs/m1/01-labrole-dissection.md`
- [ ] 2. View-only policy as IaC → `infra/cfn/iam-readonly.yaml` (`ReadOnlyPolicy`)
- [ ] 3. Assumable role as IaC → same file (`ReadOnlyRole`); explain refusal in `01-…` §6
- [ ] 4. VPC, public + private subnets → `infra/cfn/network-static.yaml`
- [ ] 5. Network in one IaC stack → stack `kv-network-static`
- [ ] 6. Quota review → `docs/m1/06-quotas.md`
- [ ] 7. Budget vs ceiling → `docs/m1/07-budget.md`
- [ ] 8. Recreatability → `docs/m1/08-recreatability.md`
- [ ] ADRs 0001 / 0002 / 0003 · README
