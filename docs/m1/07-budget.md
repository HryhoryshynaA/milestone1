# Task 7 — Monthly budget for Milestone 2 (2 shards) vs sandbox credit ceiling

Model: a hand calculation with 730 h/month (AWS convention). Change the assumptions to match your real M2 design
before the defense. Prices: us-east-1 on-demand, list.

**Verified (Nov 2026 web check):** NAT gateway $0.045/h + $0.045/GB processed; public IPv4 $0.005/h
(≈$3.65/month, also charged on NAT's Elastic IP); interface endpoint ≈ $0.01/h per AZ.
**Not re-verified (from memory — confirm in the AWS Pricing Calculator):** t3.micro $0.0104/h, gp3 $0.08/GB-month,
ALB $0.0225/h + LCU.

## Result (assumed design: 2 shards × 2 replicas = 4 × t3.micro + 4 × 20 GB gp3 + ALB; 730 h/month)
| Line | NAT off | NAT on |
|---|---:|---:|
| VPC, subnets, IGW, routes, NACL, SG, **S3 gateway endpoint** | 0.00 | 0.00 |
| 4 nodes | 30.37 | 30.37 |
| EBS | 6.40 | 6.40 |
| ALB hourly + min LCU | 22.27 | 22.27 |
| ALB public IPv4 ×2 | 7.30 | 7.30 |
| NAT hourly + EIP + 20 GB data | — | 37.40 |
| **Total / month, running 24×7** | **66.33** | **103.73** |

| Ceiling (read from the Lab page: "Used $0 of **$20**") | NAT off | NAT on |
|---|---|---|
| $20 | 332 % → **exceeds** | 519 % → **exceeds** |

Allowed run time if M2 may use at most half the ceiling ($10), `$10 ÷ (monthly cost ÷ 730 h)`:
**≈110 h/month (NAT off)**, **≈70 h/month (NAT on)** — about 3.5 h/day or 2.3 h/day.

## Conclusions to defend
1. **24×7 for a full month is 3–5× the $20 ceiling** in every variant. The design only fits if it is switched off most of the time (or shrunk, or made truly serverless).
2. **The NAT gateway is the single most expensive networking decision** (~$37/month ≈ $1.2/day ≈ 6 % of the whole $20 budget *per day* if forgotten). Hence ADR-driven default `EnableNatGateway=false`; private workloads reach S3 through the **free** gateway endpoint instead.
3. **The budget is solved by operating mode, not by shrinking the design:** run only while working. To keep M2 ≤ 50 % of the ceiling compute the allowed hours: `ceiling × 0.5 ÷ hourly cost` (e.g. $20 × 0.5 ÷ ($66.33/730 h) ≈ 110 h/month, NAT off) — this is exactly why *tear-down-and-recreate from IaC* (task 8) is a requirement, not a nicety.
4. Alternative to evaluate in M2: genuinely serverless shards (Lambda + managed storage) have ~$0 idle cost and shift the limit from budget to **quotas** (`06-quotas.md` #7–#8).
5. The Lab's displayed spend is **not real-time** — keep a safety margin; stop everything at the end of each session.

Ceiling confirmed from the Lab page: **$20**. `TODO(you)`: redo the table with your real node type/count once the M2 design is fixed.
