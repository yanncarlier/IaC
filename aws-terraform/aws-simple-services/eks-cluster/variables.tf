variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

# this is the only variable you need to change for a new cluster network vpc
variable "vpc_number" {
    description = "VPC number"
    type = string
    default = "153" 
}

variable "vpc_name" {
    description = "VPC name"
    type = string
    default = "my-vpc"
}





# variable "vpc_cidr" {
#     description = "VPC cidr"
#     type = string
#     default = "172.153.0.0/16"
# }

# variable "public_subnets" {
#   description = "A list of public subnets inside the VPC"
#   type        = list(string)
#   default     = ["172.153.0.0/20", "172.153.16.0/20", "172.153.32.0/20"]
# }

# variable "private_subnets" {
#   description = "A list of private subnets inside the VPC"
#   type        = list(string)
#   default     = ["172.153.48.0/20", "172.153.64.0/20", "172.153.80.0/20"]
# }

# 172.153.0.0/16   
#             172.153.0.0/20
#             172.153.48.0/20
#             172.153.16.0/20
#             172.153.32.0/20
#             172.153.64.0/20
#             172.153.80.0/20

