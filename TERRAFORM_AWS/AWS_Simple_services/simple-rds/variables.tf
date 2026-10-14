



provider "aws" {
  region = var.region
}

variable "region" {
  default     = "ap-northeast-2"
  description = "AWS region"
}


variable "cluster_name" {
  default = "testing"
}

# Use this:
# variable "master_password" {
#   description = "RDS root user password"
#   sensitive   = true
# }
