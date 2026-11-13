#!/usr/bin/env bash
# Asserts the spec scenarios against the LIVE stack (not against the template).
set -euo pipefail
export AWS_DEFAULT_REGION="${REGION:-us-east-1}"
NETWORK_STACK=kv-network-static
fail=0; ok(){ echo "PASS  $*"; }; bad(){ echo "FAIL  $*"; fail=1; }
q(){ aws cloudformation describe-stacks --stack-name "$NETWORK_STACK" --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }

VPC=$(q VpcId); PUB=$(q PublicSubnetIds | tr ',' ' '); PRIV=$(q PrivateSubnetIds | tr ',' ' ')
[[ -n "$VPC" ]] && ok "stack outputs readable (VPC $VPC)" || { bad "no VPC output"; exit 1; }

# main route table lookup helper: route table explicitly associated with a subnet
rt_of(){ aws ec2 describe-route-tables --filters Name=association.subnet-id,Values="$1" \
           --query 'RouteTables[0].RouteTableId' --output text; }
routes(){ aws ec2 describe-route-tables --route-table-ids "$1" \
           --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId,NatGatewayId]' --output text; }

for s in $PUB; do
  routes "$(rt_of "$s")" | grep -Eq '^0\.0\.0\.0/0[[:space:]]+igw-' \
    && ok "public $s routes 0.0.0.0/0 -> IGW" || bad "public $s has no IGW default route"
done
for s in $PRIV; do
  r="$(routes "$(rt_of "$s")")"
  echo "$r" | grep -q 'igw-' && bad "private $s has an IGW route" || ok "private $s has NO IGW route"
done

# private subnets: 0.0.0.0/0 allowed only when a NAT is deployed
NAT=$(aws cloudformation describe-stack-resources --stack-name "$NETWORK_STACK" \
        --query "StackResources[?ResourceType=='AWS::EC2::NatGateway'].PhysicalResourceId" --output text)
for s in $PRIV; do
  has_default=$(routes "$(rt_of "$s")" | grep -c '^0\.0\.0\.0/0' || true)
  if [[ -z "$NAT" && "$has_default" -ne 0 ]]; then bad "private $s has default route but no NAT"; else ok "private $s default-route state consistent (NAT=${NAT:-none})"; fi
done

# addressing: 4 subnets, no overlaps (python is on every dev box; stdlib only)
aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC" --query 'Subnets[].CidrBlock' --output text | python3 -c '
import sys, ipaddress as ip
n=[ip.ip_network(x) for x in sys.stdin.read().split()]
assert len(n)==4, f"expected 4 subnets, got {len(n)}"
assert not any(a.overlaps(b) for i,a in enumerate(n) for b in n[i+1:]), "overlap"
print("PASS  4 subnets, no overlap:", ", ".join(map(str,sorted(n))))' || fail=1

exit $fail
