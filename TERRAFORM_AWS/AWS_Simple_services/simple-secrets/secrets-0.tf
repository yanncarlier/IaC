# terraform scripts to dynamic generate aws eks kubernetes cluster secrets 

# Here is an example of how you can use Terraform to dynamically 
# generate secrets for an Amazon Web Services (AWS) Elastic Kubernetes Service (EKS) 
# cluster:

resource "random_string" "eks_cluster_name" {
  length  = 8
  special = false
}

resource "random_string" "eks_cluster_admin_password" {
  length  = 16
  special = true
}

resource "aws_eks_cluster" "example" {
  name     = "eks-${random_string.eks_cluster_name.result}"
  role_arn = aws_iam_role.example.arn
}

resource "aws_iam_role" "example" {
  name = "eks-${random_string.eks_cluster_name.result}-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "example" {
  name = "eks-${random_string.eks_cluster_name.result}-policy"
  role = aws_iam_role.example.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_eks_cluster_auth" "example" {
  name = aws_eks_cluster.example.name
}

resource "local_file" "eks_kubeconfig" {
  content  = aws_eks_cluster_auth.example.kubeconfig
  filename = "${path.module}/kubeconfig-${random_string.eks_cluster_name.result}"
}


# This code creates a new EKS cluster with a random name, 
# using a role and policy with random name, and also creates a new IAM role 
# with random name, and assigns the necessary permissions to it.
# It also creates a new "aws_eks_cluster_auth" resource that will generate 
# the necessary authentication information for the cluster, and stores it 
# in a kubeconfig file.

# You can use the random_string resource to generate random strings, 
# which can be used as the cluster name and admin password. This way you can 
# make sure that your secrets are unique and hard to guess.

# Please be aware that the above code is just an example and it's 
# recommended to use more secure methods to manage your secrets, 
# like using Hashicorp Vault or AWS Secrets Manager.

# Also, you should be aware of the cost of using AWS services.
