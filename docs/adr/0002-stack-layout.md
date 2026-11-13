# ADR-0002: Stack layout — separate stacks, split by *rate of change* and *deployability*

- Status: accepted (M1) · Spec: `openspec/changes/m1-infrastructure-setup`

## Context
Task 5 asks for a stack holding the network. Task 2–3 produce IAM resources the sandbox cannot
create. Milestone 2 will add an application. The lecturer's convention (2026-09-17): name stacks
**static** (not re-applied on every deploy; rarely changes; some resources are slow or fail if
re-created, e.g. S3 buckets, roles) vs **dynamic** (updated on every deploy, e.g. the app).
Cross-stack references let the app stack use the network without owning it.

## Options considered
| Option | For | Against |
|---|---|---|
| One stack for everything | Simple, one command | The IAM resources are **refused** by the sandbox → whole stack rolls back, taking the VPC with it. Any later app change re-evaluates the network. Blast radius = everything |
| **Three stacks: `network-static`, `iam-readonly`, (M2) app-dynamic** ✔ | A refused IAM stack cannot hurt the network; network is changed deliberately; app deploys fast and often; matches lecture convention | Cross-stack exports to manage; export in use blocks network deletion (need order: app first, network last) |
| Nested stacks | One entry point | Hides failures one level deeper; more to explain; no benefit at this size |

## Decision
1. `kv-network-static` — VPC, subnets, IGW, routing, NACLs, SG, S3 endpoint, optional NAT. **Deployed.**
2. `kv-iam-readonly` — view-only policy + assumable role. **Delivered as code, validated, deployment expected to be refused** (sandbox grants no `iam:CreatePolicy` / `iam:CreateRole`).
3. M2 application stack(s) will be *dynamic* and import values via `Fn::ImportValue` (`kv-network-static-VpcId`, …).

The "-static" suffix is a naming convention only (it is not a CloudFormation feature): static
stacks are applied manually; dynamic stacks are applied by the pipeline on every deploy.

## Consequences
- (+) Teardown order is explicit: dynamic → network. Rebuild order: network → dynamic.
- (+) The expected IAM failure is an *evidence artifact* (task 3), not a broken build.
- (−) Exports create a hard dependency; renaming an exported value requires a migration.

## Where this lives in code
Files `infra/cfn/network-static.yaml`, `infra/cfn/iam-readonly.yaml`; stack names in `scripts/deploy.sh` / `teardown.sh`; exports in the `Outputs:` of the network template.

## Revisit when
M2 needs resources that must outlive teardown (buckets with data) → give them their own static stack with `DeletionPolicy: Retain`.
