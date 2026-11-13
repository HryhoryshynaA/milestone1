# Task 6 — Service quotas that can limit Milestone 2

Read the **measured** value for this sandbox (console: *Service Quotas*; or CLI: `aws service-quotas list-service-quotas --service-code ec2` — repeat for `vpc`, `lambda`, `apigateway`, `elasticloadbalancing`, `dynamodb`) and paste it into the right column.
AWS "default" values are given only as a reference; they are not what you will necessarily get
(the lecturer's own autoscaling demo died when his account's quota was cut the day before class).
Also check **Learner Lab-specific caps**, which are *not* in Service Quotas.

Design assumed for M2: 2 shards × 2 replicas = 4 compute nodes in the private tier, a public entry
point, S3 for snapshots, optional NAT.

| # | Quota | Why it can bite M2 | AWS default (ref., verify) | Measured here `TODO(you)` | Adjustable? |
|---|---|---|---|---|---|
| 1 | EC2 running On-Demand Standard vCPUs | 4 nodes × vCPU each; scaling to 3+ shards | new accounts are low (single digits) | | |
| 2 | Learner Lab: concurrent EC2 instances / vCPU cap | documented cap (≈9 instances in us-east-1, 32 vCPU) | n/a (Academy policy) | | no |
| 3 | Elastic IPs per Region | each NAT gateway needs one; ALB/public IPs also count toward cost | 5 | | |
| 4 | NAT gateways per AZ | NAT-per-AZ design | 5 | | |
| 5 | VPCs per Region / Internet gateways per Region | rebuild tests: leftover VPCs from failed attempts eat the limit | 5 / 5 | | |
| 6 | Security groups per VPC; rules per SG | one SG per shard + references | 2 500 / 60 | | |
| 7 | Lambda concurrent executions | per-request fan-out to shards; a *serverless* store lives or dies here | 1 000 (new accounts may be much lower) | | |
| 8 | API Gateway throttle (account) / integration timeout | benchmark in M2 will hit throttle first | 10 000 rps / 29 s | | |
| 9 | ALB per Region / targets per ALB | entry point | 50 / 1 000 | | |
| 10 | DynamoDB table count (if used for metadata/shard map) | shard map / membership table | 2 500 | | |
| 11 | Learner Lab **budget** (not a quota, but a hard stop) | see `07-budget.md` | **$20** (Lab page shows "Used $0 of $20") | $20 | no |

**Which will actually limit me** (`TODO(you)` after measuring) — likely candidates: #1/#2 (compute count),
#7/#8 (serverless throughput during the benchmark), #3 (EIPs if NAT is on).
**Mitigations**: keep replicas small; one NAT, not per AZ; request increases early where *Adjustable = yes*
(can take days); design the benchmark to ramp, not spike.
