
# AWS VPC Terraform module
# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest  
# https://github.com/terraform-aws-modules/terraform-aws-vpc  


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.2"

  name = var.vpc_name

  cidr = "172.${var.vpc_number}.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["172.${var.vpc_number}.0.0/20", "172.${var.vpc_number}.16.0/20", "172.${var.vpc_number}.32.0/20"]
  public_subnets  =  ["172.${var.vpc_number}.48.0/20", "172.${var.vpc_number}.64.0/20", "172.${var.vpc_number}.80.0/20"]

  
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}


# default = "172.${var.vpc_number}.0.0/16"