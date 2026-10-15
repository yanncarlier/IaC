# Create another file named variables.tf and paste the following code:
variable "rds_username" {
  type = string
}

variable "rds_password" {
  type = string
}

variable "rds_host" {
  type = string
}

variable "jumpbox_private_key_path" {
  type    = string
  default = "~/.ssh/id_rsa"
}

# In the code above, we define four input variables that we will use later in our Terraform configuration.

