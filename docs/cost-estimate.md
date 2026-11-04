# Cost estimate

Estimated with the [AWS Pricing Calculator](https://calculator.aws) for **us-east-1**,
On-Demand pricing, with every resource running 24/7 (730 hours per month).

- Shared estimate: https://calculator.aws/#/estimate?id=beec94fc8df038f979d595bd125c063463a0e21e
- Raw export: [cost/aws-pricing-estimate.csv](cost/aws-pricing-estimate.csv)

| Component | Configuration | Monthly cost (USD) | Share |
|---|---|---:|---:|
| NAT Gateway | 1 zonal NAT Gateway | 33.03 | 32 % |
| Amazon EC2 | 3 × `t3.micro` (2 backend + 1 frontend), 8 GB gp3 each | 24.70 | 24 % |
| Application Load Balancer | 1 ALB, low traffic | 16.66 | 16 % |
| Amazon RDS for MySQL | 1 × `db.t3.micro`, Single-AZ, 20 GB gp3 | 14.71 | 14 % |
| Public IPv4 addresses | 4 (NAT Gateway, ALB × 2, frontend) | 14.60 | 14 % |
| **Total** | | **103.70** | **100 %** |

Not included, as negligible at this scale: data transfer, S3 state bucket, CloudWatch metrics,
and the Secrets Manager secret holding the database password (about 0.40 USD per month).

**Cost of a demo session**: about **0.14 USD per hour**, so roughly **0.30 USD** for a two-hour
session followed by `terraform destroy`.

## Analysis

**Networking costs more than compute.** The NAT Gateway, the load balancer and the public IPv4
addresses account for 64.29 USD, about **62 % of the bill**, while the servers and the database
account for 38 %.

**The NAT Gateway is the largest single item** (32 %), although it is only used by private instances
to download packages and the application code at boot.

**Almost every cost is fixed.** Each item is billed by the hour as long as it exists, whatever the
traffic: with no users at all, the architecture still costs about 100 USD per month. Traffic-dependent
costs (load balancer capacity units, data processed by the NAT Gateway) are negligible at this scale.

## Cost optimisation options

| Option | Saving | Trade-off |
|---|---|---|
| Destroy the stack when not in use (current practice) | almost the whole bill | the infrastructure must be recreated (about 15 minutes) before each demo |
| Custom AMI with dependencies preinstalled (Packer), plus VPC endpoints for AWS services | could remove the NAT Gateway (~33 USD) | an image build pipeline to maintain; instances can no longer reach the Internet |
| Frontend on S3 + CloudFront instead of EC2 | one instance and one public IPv4 (~11 USD) | not allowed by the project brief |
| Graviton instances (`t4g.micro`, `db.t4g.micro`) | about 20 % on EC2 instances, less on RDS | ARM architecture: dependencies must support it |
| Savings Plans or Reserved Instances | up to about 70 % on EC2 and RDS (3-year commitment) | a 1- or 3-year commitment, only worth it for a permanent workload |

**Production view.** A production setup would add a second NAT Gateway and Multi-AZ RDS, which would
roughly add 33 USD and 15 USD per month. The cost of high availability is a business decision that must be
weighed against the cost of downtime.

See also the [Well-Architected review](well-architected-review.md), whose cost optimization pillar builds on this estimate.
