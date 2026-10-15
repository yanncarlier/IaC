# Terraform to create an Elastic Kubernetes (EKS)  cluster with 
# auto scale

# Here is an example of how you can use Terraform to 
# create an Elastic Kubernetes (EKS) cluster with auto-scaling:


provider "aws" {
  version = "~> 2.0"
  region  = "us-west-2"
}

module "eks_cluster" {
  source           = "terraform-aws-modules/eks/aws"
  cluster_name     = "example-cluster"
  subnets          = ["subnet-1", "subnet-2", "subnet-3"]
  vpc_id           = "vpc-1"
  desired_capacity = 3
  min_size         = 3
  max_size         = 6
}

module "worker_group_asg" {
  source               = "terraform-aws-modules/asg/aws"
  cluster_name         = module.eks_cluster.cluster_name
  asg_desired_capacity = 3
  asg_min_size         = 3
  asg_max_size         = 6
  vpc_id               = module.eks_cluster.vpc_id
  subnets              = module.eks_cluster.worker_subnets
}


# This code uses the terraform-aws-modules/eks/aws module to create 
# an EKS cluster with the name "example-cluster" in the us-west-2 region.
# It also sets the subnets, VPC ID, desired capacity, minimum size, 
# and maximum size for the worker nodes.

# Additionally, the terraform-aws-modules/asg/aws module is used to
# create an Auto Scaling Group (ASG) for the worker nodes, 
# with the desired capacity, minimum size, and maximum size specified.

# Please note that this code is just an example, and you should adjust 
# the cluster name, region, subnets, VPC ID, desired capacity, 
# minimum size, and maximum size according to your specific requirements.

# Also, Terraform uses AWS IAM roles to manage the resources, and it 
# is assumed that the necessary IAM permissions are granted to the 
# executing user/role.



