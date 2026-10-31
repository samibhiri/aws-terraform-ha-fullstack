# AWS Highly-Available Full-Stack Deployment with Terraform

Deploying a full-stack web application on AWS using Terraform: custom VPC,
load balancing, auto scaling and a managed database.

🚧 **Work in progress**: the infrastructure is being built step by step.

## Roadmap

- [ ] Networking (VPC, subnets, gateways) — *in progress*
- [ ] Security groups
- [ ] Database (RDS)
- [ ] Backend (EC2, Auto Scaling, Load Balancer)
- [ ] Frontend

## Architecture (current state)

```mermaid
flowchart TB
    internet((Internet))

    subgraph VPC["VPC 10.0.0.0/16"]
        igw[Internet Gateway]
        rt[Public route table<br/>0.0.0.0/0 → IGW]

        subgraph AZA["AZ A"]
            pubA[Public subnet<br/>10.0.1.0/24]
        end

        subgraph AZB["AZ B"]
            pubB[Public subnet<br/>10.0.2.0/24]
        end
    end

    internet <--> igw
    igw --- rt
    rt --- pubA
    rt --- pubB
```
