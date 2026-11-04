# Architecture decisions

This document records the main design decisions of the project: the context, the option chosen,
the alternatives considered and the trade-offs. Several choices are deliberately optimised for
**cost and learning** rather than production; each section states what would change in production.

| # | Decision | Status |
|---|---|---|
| 1 | [Terraform for all infrastructure](#1-terraform-for-all-infrastructure) | Accepted |
| 2 | [Two Availability Zones, public and private subnets](#2-two-availability-zones-public-and-private-subnets) | Accepted |
| 3 | [A single NAT Gateway](#3-a-single-nat-gateway) | Accepted (cost) |
| 4 | [EC2 Auto Scaling group for the backend](#4-ec2-auto-scaling-group-for-the-backend) | Accepted |
| 5 | [Application Load Balancer in front of the API](#5-application-load-balancer-in-front-of-the-api) | Accepted |
| 6 | [Amazon RDS for MySQL, Single-AZ](#6-amazon-rds-for-mysql-single-az) | Accepted (cost) |
| 7 | [Static frontend on an EC2 instance](#7-static-frontend-on-an-ec2-instance) | Accepted (project constraint) |
| 8 | [Security groups chained by reference, no SSH](#8-security-groups-chained-by-reference-no-ssh) | Accepted |
| 9 | [Database password handling](#9-database-password-handling) | Accepted |
| 10 | [CI/CD with OIDC and manual deployments](#10-cicd-with-oidc-and-manual-deployments) | Accepted |
| 11 | [Remote state in S3 with native locking](#11-remote-state-in-s3-with-native-locking) | Accepted |

---

## 1. Terraform for all infrastructure

**Context.** The infrastructure must be reproducible, reviewable and destroyable on demand,
since it is billed by the hour.

**Decision.** Every AWS resource is defined in Terraform. No resource is created by hand,
except the bootstrap resources Terraform itself depends on (state bucket, CI/CD IAM roles).

**Alternatives.**
- **AWS CloudFormation / CDK**: native to AWS, no state file to manage, but AWS-only.
- **Elastic Beanstalk**: much faster to set up, but hides the networking and scaling components
  (and was excluded by the project brief).

**Trade-offs.** Terraform requires managing a state file (see decision 11), in exchange for a
cloud-agnostic language, a readable `plan` before every change and a large ecosystem.

---

## 2. Two Availability Zones, public and private subnets

**Context.** The application must survive the loss of one Availability Zone, and the backend and
database must not be reachable from the Internet.

**Decision.** One VPC (`10.0.0.0/16`) spanning two AZs, each with one public subnet (load balancer,
frontend, NAT Gateway) and one private subnet (backend instances, database).

**Alternatives.**
- **Three AZs**: higher availability and better tolerance during an AZ outage, at a higher cost
  (more NAT Gateways, more instances to keep the same capacity per AZ).
- **A single AZ**: cheaper, but no high availability.

**Trade-offs.** Two AZs is the minimum for an ALB and for meaningful high availability.
`/24` subnets leave plenty of room, and the `10.0.0.0/16` VPC can host more subnets later.

---

## 3. A single NAT Gateway

**Context.** Private instances need outbound Internet access (package installation, `git clone`).
A NAT Gateway is billed per hour and per GB.

**Decision.** A single NAT Gateway, in the public subnet of AZ A, shared by both private subnets.

**Alternatives.**
- **One NAT Gateway per AZ**: no cross-AZ dependency, the recommended production setup.
- **VPC endpoints** (S3, SSM…) to avoid NAT traffic for AWS services.
- **No NAT**: bake dependencies into a custom AMI (Packer) so instances need no Internet access.

**Trade-offs.** If AZ A fails, instances in AZ B lose outbound access. They keep serving traffic,
but new instances cannot bootstrap. Acceptable for a demo; in production, one NAT Gateway per AZ.

---

## 4. EC2 Auto Scaling group for the backend

**Context.** The API must stay available when an instance fails and absorb load peaks.

**Decision.** Backend instances are launched by an Auto Scaling group (min 2, desired 2, max 4)
across both private subnets, from a launch template whose user data installs and starts the API
as a `systemd` service. A target-tracking policy keeps average CPU around 70 %.

**Alternatives.**
- **Amazon ECS on Fargate**: containers, no server to manage, faster deployments.
- **AWS Lambda + API Gateway**: serverless, pay per request, ideal for irregular traffic.
- **A custom AMI** (Packer) instead of bootstrapping at boot: faster and more reliable scale-out.

**Trade-offs.** EC2 + ASG exposes every building block (launch template, health checks, scaling)
and was required by the brief. Bootstrapping from user data makes scale-out slower (several
minutes) and depends on external sources (package repositories, GitHub).

---

## 5. Application Load Balancer in front of the API

**Context.** Traffic must be spread across healthy instances, and clients need a stable endpoint
while instances come and go.

**Decision.** An internet-facing ALB in both public subnets, an HTTP listener on port 80, and a
target group with a health check on `GET /health`. The ASG uses ELB health checks, so an instance
whose API stops responding is replaced, not only one whose machine fails.

**Alternatives.**
- **Network Load Balancer**: layer 4, higher performance, static IPs, but no HTTP routing.
- **API Gateway**: throttling, API keys and authentication built in, better suited to Lambda.

**Trade-offs.** The ALB has a fixed hourly cost, even without traffic. HTTP only for now: HTTPS
requires a domain name and an ACM certificate (listed as an improvement).

---

## 6. Amazon RDS for MySQL, Single-AZ

**Context.** The application needs a relational database without managing a database server.

**Decision.** RDS for MySQL 8.0, `db.t3.micro`, in a DB subnet group spanning both private subnets,
not publicly accessible, Single-AZ.

**Alternatives.**
- **Multi-AZ**: a synchronous standby in the second AZ with automatic failover (about twice the cost).
- **Amazon Aurora (Serverless v2)**: higher availability and automatic scaling, at a higher cost.
- **DynamoDB**: serverless and highly available by default, but a different data model.

**Trade-offs.** Single-AZ is the main single point of failure of the architecture: if AZ A fails,
the database is unavailable. Production would use Multi-AZ, automated backups with a retention
period, and deletion protection (`skip_final_snapshot` would be disabled).

---

## 7. Static frontend on an EC2 instance

**Context.** The brief requires the frontend to be served by an EC2 instance with nginx or Apache.

**Decision.** A single EC2 instance in a public subnet serves the static files with nginx.
At boot, it generates `config.js` with the ALB DNS name, so the browser always calls the API
through the load balancer, never a backend instance.

**Alternatives.**
- **Amazon S3 + CloudFront**: the standard pattern for static sites, highly available, cached
  worldwide, HTTPS included, no server to patch, and almost free at low traffic.

**Trade-offs.** The frontend instance is a single point of failure, and must be patched and
monitored. Outside the constraints of the brief, S3 + CloudFront would be the clear choice.

---

## 8. Security groups chained by reference, no SSH

**Context.** Each layer should only be reachable by the layer directly in front of it.

**Decision.**
- The backend security group accepts the API port **only from the ALB security group**,
  and the database security group accepts MySQL **only from the backend security group**.
  Rules reference security groups, not IP ranges.
- No SSH port is open: instances are administered through **SSM Session Manager**,
  using an instance profile with `AmazonSSMManagedInstanceCore`.

**Alternatives.**
- **CIDR-based rules** (for example, the private subnet ranges): simpler, but any resource in the
  range would be allowed.
- **A bastion host with SSH**: an extra instance to secure and keys to manage.

**Trade-offs.** None significant. Security group references keep working when instances are
replaced and their IP addresses change, and Session Manager sessions can be logged.

---

## 9. Database password handling

**Context.** The database password must never be stored in the repository, and should not be copied
into places that are not designed to hold secrets.

**Decision.** RDS **generates and rotates** the master password and stores it in **AWS Secrets Manager**
(`manage_master_user_password = true`). Backend instances receive only the ARN of the secret; at startup,
the API reads the secret with the IAM role of its instance, which is allowed to call
`secretsmanager:GetSecretValue` on this secret only. If RDS rotates the password, the API reloads the
secret and reconnects.

**Alternatives.**
- **A `sensitive` Terraform variable passed through user data** (the first version of this project):
  the password ended up in the Terraform state and in the launch template user data.
- **SSM Parameter Store (`SecureString`)**: free in its standard tier, but no native rotation
  and no integration with RDS.

**Trade-offs.** About 0.40 USD per secret per month, and the application depends on Secrets Manager
at startup. In exchange, nobody needs to know the password, every read is logged in CloudTrail,
and the password is rotated automatically.

---

## 10. CI/CD with OIDC and manual deployments

**Context.** Infrastructure changes must be reviewed before being applied, without storing
long-lived AWS keys in GitHub.

**Decision.**
- Every pull request runs `fmt`, `validate`, `tflint` and a `terraform plan`, posted as a comment.
  Both checks are required to merge into the protected `main` branch.
- GitHub Actions authenticates to AWS with **OIDC**: each run receives credentials valid for
  one hour. Two roles: a **read-only** role for plans, and a deployment role that only workflows
  running on `main` can assume.
- Deployments (`apply` / `destroy`) are **triggered manually**, with a confirmation input.

**Alternatives.**
- **Access keys stored as GitHub secrets**: simpler, but long-lived credentials that can leak.
- **Automatic `apply` on merge**: true continuous deployment, but a merge would immediately
  create billable infrastructure.
- **Terraform Cloud / HCP Terraform**: managed state, plans and approvals.

**Trade-offs.** The deployment role currently uses `AdministratorAccess`, restricted to the `main`
branch by its trust policy. A least-privilege policy is planned. The trust policies match GitHub's
`sub` claim with the immutable owner and repository IDs, so a re-created repository with the same
name cannot assume the roles.

---

## 11. Remote state in S3 with native locking

**Context.** CI runners are ephemeral: a local state file would be lost after each run.

**Decision.** The state is stored in a versioned, encrypted S3 bucket with public access blocked,
with **S3 native locking** (`use_lockfile`). Pull request plans run with `-lock=false`, because
their role is read-only.

**Alternatives.**
- **S3 + DynamoDB table** for locking: the historical approach, now superseded by native locking.
- **HCP Terraform**: managed state and locking, without a bucket to maintain.

**Trade-offs.** The bucket is created by hand (it must exist before Terraform can use it).
Bucket versioning makes it possible to restore a previous state after a mistake.
