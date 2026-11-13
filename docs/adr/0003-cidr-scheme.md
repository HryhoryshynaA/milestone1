# ADR-0003: CIDR addressing scheme — 10.42.0.0/16 with tier bands

- Status: accepted (M1)

## Context
Subnets must not overlap, must leave room for M2+ (a data tier, more AZs), and the VPC must
not collide with networks we might connect later (the lecture's "what if the university buys
another one and we merge networks" example: overlapping ranges make routing impossible).
Two ranges are already in use in a fresh account: the **default VPC 172.31.0.0/16** and the
console's suggested **10.0.0.0/16**.

## Options considered
| Option | Verdict |
|---|---|
| `10.0.0.0/16` (console default) | ✗ collides with the most common default in every company/lab; first to overlap in a future peering |
| `172.31.0.0/16` | ✗ is the default VPC |
| `192.168.0.0/16` | ✗ clashes with home/office LANs when connecting by VPN |
| **`10.42.0.0/16`** ✔ | 65 536 addresses, private (RFC 1918), unusual enough to avoid common clashes |
| Larger (`/8`) or smaller (`/24`) VPC | ✗ /8 is not allowed (AWS max /16); /24 leaves no room for tiers |

## Decision
VPC `10.42.0.0/16`. Carve **/24 slices** (251 usable hosts each — AWS reserves 5), numbered by the
third octet, in **bands** so the tier is readable from the address:

| Band (3rd octet) | Tier | Built in M1 | Subnets |
|---|---|---|---|
| 0–15 | public | yes | `10.42.0.0/24` (AZ-a), `10.42.1.0/24` (AZ-b) |
| 16–31 | private (application) | yes | `10.42.16.0/24` (AZ-a), `10.42.17.0/24` (AZ-b) |
| 32–47 | data (shards/replicas) | **reserved**, not created | `10.42.32.0/24`, `10.42.33.0/24` |
| 48–255 | unallocated | — | future (3rd AZ, mgmt, …) |

Subnet CIDRs are **computed**, not typed: `Fn::Select [index, Fn::Cidr [VpcCidr, 64, 8]]` — so
changing `VpcCidr` (any /16) re-derives all subnets consistently and cannot produce an overlap.
The template's `VpcCidr` parameter pattern forces a `/16` because the bands assume it.

## Consequences
- (+) Reading `10.42.17.x` tells you "private, AZ-b" without opening the console.
- (+) Adding a third AZ = add index 2 / 18 / 34; no renumbering.
- (−) /24 per subnet caps a tier-AZ at 251 hosts; fine for 2 shards. Lambda ENIs/endpoint ENIs would count against it — revisit if M2 uses VPC-attached Lambda at scale.
- (−) Bands waste address space on purpose (cheap, since private space is free).

## Where this lives in code
`infra/cfn/network-static.yaml` → `VpcCidr` parameter and the four `AWS::EC2::Subnet` resources
(`!Select [0|1|16|17, !Cidr [!GetAtt Vpc.CidrBlock, 64, 8]]`). Independent check:
```python
import ipaddress as ip
s = list(ip.ip_network('10.42.0.0/16').subnets(new_prefix=24))
for i in (0, 1, 16, 17): print(i, s[i])   # public-a, public-b, private-a, private-b
```

## Revisit when
We need to peer with another network that uses 10.42/16, or a tier needs > 251 addresses per AZ.
