# AWS Simple Services

Terraform examples for learning how common AWS and Kubernetes-adjacent resources fit together. Each directory is an independent example or snippet; this repository is **not** a single Terraform root module. Run Terraform from the directory for the one example you intend to use—never from this repository root.

> **Learning material, not production infrastructure.** Several examples use placeholder values, older provider or platform versions, public network access, and credentials embedded in configuration. Review and adapt every setting before applying anything to an AWS account.

## Contents

| Directory | Purpose | Notes |
| --- | --- | --- |
| [`simple-eks-cluster`](simple-eks-cluster/) | Creates a VPC and an EKS cluster with two managed node groups. | The most complete example. It creates chargeable resources, including a NAT gateway and EC2 worker nodes. |
| [`simple-rds`](simple-rds/) | Aurora MySQL cluster, instances, VPC, subnet group, and security group. | Based on a HashiCorp learning example; see its [README](simple-rds/README.md). Requires security and credential changes before use. |
| [`simple-ecr`](simple-ecr/) | Private ECR repository plus a sample IAM policy and role. | Uses a fixed AWS region and resource names. |
| [`simple-jumpbox`](simple-jumpbox/) | EC2 jump-host and connection-output example. | AMI, key pair, and ingress settings are placeholders/insecure as written. |
| [`simple-acl-sg`](simple-acl-sg/) | Network ACL and security-group rule snippets. | References VPC and subnet resources that are not defined in this directory. |
| [`simple-docker-images`](simple-docker-images/) | Pulls a Docker image from a GitLab registry. | Requires Docker, provider setup, and GitLab credentials; avoid putting passwords in command lines. |
| [`simple-ets-chart`](simple-ets-chart/) | Helm release example. | Uses intentionally fictitious chart and image values. |
| [`simple-secrets`](simple-secrets/) | Examples of generated and Kubernetes secrets. | Files contain alternative examples with duplicate resource names; use one pattern in its own Terraform module, not all at once. |

## Prerequisites

- Terraform. The EKS example declares Terraform `~> 1.3`; other examples do not consistently pin a Terraform version.
- AWS credentials supplied through a supported mechanism such as an AWS CLI profile, environment variables, or an assumed IAM role.
- Permissions appropriate to the selected example. EKS and RDS need broad permissions for networking, IAM, and their respective AWS services.
- Additional local tooling for particular snippets:
  - Docker for `simple-docker-images`
  - Kubernetes access and the Kubernetes provider for Kubernetes-secret examples
  - Helm provider configuration for `simple-ets-chart`

## Quick start

Choose one directory, inspect its code, and make configuration changes before planning. For example, to work with the EKS configuration:

```bash
cd simple-eks-cluster
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Only after reviewing the plan and confirming the selected AWS account and region should you run:

```bash
terraform apply
```

When the environment is no longer needed, remove the resources from the same directory and state:

```bash
terraform destroy
```

Do not copy a plan, state file, or `.terraform` directory between examples. Use a separate remote state backend and locking strategy for any shared or long-lived environment.

## EKS configuration

`simple-eks-cluster` uses the community VPC and EKS modules. Its primary inputs are defined in [`variables.tf`](simple-eks-cluster/variables.tf):

| Variable | Default | Meaning |
| --- | --- | --- |
| `region` | `ap-northeast-2` | AWS region for the cluster and VPC. |
| `vpc_number` | `153` | Second octet used to construct the VPC CIDR (`172.<vpc_number>.0.0/16`). Choose a non-overlapping private range. |
| `vpc_name` | `my-vpc` | Name assigned to the VPC. |

Prefer a local, uncommitted variable file for values specific to your account:

```hcl
# terraform.tfvars
region     = "ap-northeast-2"
vpc_number = "20"
vpc_name   = "training-eks-vpc"
```

The `.gitignore` already excludes `*.tfvars`, Terraform state, generated kubeconfigs, and private-key files. Do not override that protection by committing credentials or generated state.

After a successful EKS apply, retrieve connection details with:

```bash
terraform output
aws eks update-kubeconfig --region "$(terraform output -raw region)" --name "$(terraform output -raw cluster_name)"
kubectl get nodes
```

The EKS example currently enables a public control-plane endpoint and pins older module, provider, and Kubernetes versions. Restrict endpoint access, review supported Kubernetes versions, and upgrade dependencies before using it beyond experimentation.

## Security and cost checklist

Before applying any example, at minimum:

- Confirm the AWS account, region, resource names, CIDR ranges, and plan.
- Replace every hard-coded password, key name, AMI, registry credential, and placeholder with environment-specific configuration. Store secrets in a managed secret system and mark sensitive Terraform inputs and outputs as sensitive.
- Restrict security-group and network-ACL ingress. The RDS and jumpbox examples include rules that allow broad access; do not expose SSH or database ports to `0.0.0.0/0`.
- Use current, supported AMIs, providers, modules, database engines, and Kubernetes versions.
- Configure backups, deletion protection, encryption, logging, tagging, and a remote state backend for anything persistent.
- Budget for running resources. EKS control planes, NAT gateways, EC2 nodes, Aurora instances, storage, and data transfer can incur charges.

## Repository conventions

Format and validate only the example you are editing:

```bash
terraform fmt -check
terraform validate
```

Terraform state can contain infrastructure metadata and secrets. Keep it out of version control, protect access to any remote backend, and use state locking for collaborative work.

## License and attribution

The `simple-rds` directory includes its own MPL-2.0 license and states that it is a companion to HashiCorp's RDS learning tutorial. Other examples include comments and links referencing community sources. No repository-wide license is currently supplied; confirm licensing before redistributing code outside the scope of the included `simple-rds` license.
