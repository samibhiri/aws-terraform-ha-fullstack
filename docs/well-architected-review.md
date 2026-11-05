# Well-Architected review

A self-assessment against the six pillars of the
[AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html).
Gaps are listed deliberately: they are the backlog of a production version.

## Operational excellence

| In place | Gaps |
|---|---|
| All infrastructure defined as code (Terraform), reviewed through pull requests | No CloudWatch dashboards or alarms (API errors, unhealthy targets, RDS CPU and storage) |
| CI checks (`fmt`, `validate`, `tflint`) and a `terraform plan` on every pull request | Application logs stay on the instances (no CloudWatch Logs agent) |
| One-click, repeatable deployment and destruction from GitHub Actions | No runbook for incidents yet |
| Instances bootstrap themselves from user data: no manual configuration | |

## Security

| In place | Gaps |
|---|---|
| Backend and database in private subnets, no public endpoint for RDS | HTTP only: no TLS between users and the load balancer |
| Security groups chained by reference: API reachable only from the ALB, database only from the backend | Inline policies on project roles are not capped by a permissions boundary |
| No SSH port open: administration through SSM Session Manager | No AWS WAF in front of the load balancer |
| CI/CD authenticates with OIDC: no long-lived AWS keys; deployment role restricted to `main` | RDS storage encryption and CloudTrail not explicitly configured |
| State bucket encrypted, versioned, public access blocked | |
| Database password generated and rotated by RDS in Secrets Manager, readable only by the backend instance role | |
| Deployment role restricted by a least-privilege IAM policy, versioned in the repository | |

## Reliability

| In place | Gaps |
|---|---|
| Two Availability Zones, ALB across both public subnets | RDS Single-AZ: the database is the main single point of failure |
| Auto Scaling group (min 2) spread across AZs, with ELB health checks: failed instances are replaced automatically | Single NAT Gateway: AZ B depends on AZ A for outbound access |
| Infrastructure can be rebuilt from code at any time | Frontend served by a single EC2 instance |
| | Database backup retention left at the default, and restoring a backup has never been tested |

## Performance efficiency

| In place | Gaps |
|---|---|
| Horizontal scaling: target tracking keeps average CPU around 70 % (2 to 4 instances) | No caching layer (CloudFront for the frontend, ElastiCache for the API) |
| Load balancer spreads traffic across healthy targets | Scale-out is slow: new instances install everything at boot (a custom AMI would cut this to about a minute) |
| Burstable instance types sized for a small workload | No load test to validate the scaling thresholds |

## Cost optimization

| In place | Gaps |
|---|---|
| Smallest instance sizes, Single-AZ database and a single NAT Gateway for the demo | No cost allocation report or AWS Budgets alert defined in code |
| Resources tagged with `Project` and `ManagedBy` (default tags) for cost allocation | Fixed hourly costs dominate (see the [cost estimate](cost-estimate.md)) |
| The stack is destroyed after each session | |

## Sustainability

| In place | Gaps |
|---|---|
| Resources exist only while needed (destroyed after use) | Graviton (ARM) instances would use less energy for the same work |
| Auto scaling removes instances when load drops | Frontend on S3 + CloudFront would avoid an always-on server |

## Next steps

- Run a formal review with the [AWS Well-Architected Tool](https://aws.amazon.com/well-architected-tool/)
