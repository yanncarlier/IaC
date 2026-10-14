# Here is an example Terraform script that creates an Amazon Elastic Container Registry (ECR) private registry:

provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_ecr_repository" "private_registry" {
  name = "my-private-registry"
}

resource "aws_iam_policy" "ecr_policy" {
  name = "ecr_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ],
        Effect   = "Allow",
        Resource = "${aws_ecr_repository.private_registry.arn}"
      }
    ]
  })
}

resource "aws_iam_role" "ecr_role" {
  name = "ecr_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        # Principal = {
        #   Service = "ecr.amazonaws.com"
        # }
        Principal = {
          "Service" : ["eks.amazonaws.com"]
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_policy_attachment" {
  policy_arn = aws_iam_policy.ecr_policy.arn
  role       = aws_iam_role.ecr_role.name
}


# In this example, the AWS provider is configured to use the us-west-2 region. 
# An ECR repository named my-private-registry is created, 
# and an IAM policy and role are created to allow access to
#  the repository. The policy is then attached to the role.

















