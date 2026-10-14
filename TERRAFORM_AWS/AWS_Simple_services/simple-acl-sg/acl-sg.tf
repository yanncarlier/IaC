
# terraform code to create aws acl and security groups for a kubernetes 
# eks cluster


# Here is an example of Terraform code that can be used to create an 
# Amazon Web Services (AWS) Access Control List (ACL) and security groups 
# for a Kubernetes Elastic Kubernetes Service (EKS) cluster:

resource "aws_network_acl" "example" {
  vpc_id = aws_vpc.example.id
  subnet_ids = [aws_subnet.example.id]
}

resource "aws_security_group" "example" {
  name        = "example"
  description = "Example security group"
  vpc_id      = aws_vpc.example.id
}

resource "aws_security_group_rule" "example" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.example.id
}

resource "aws_security_group_rule" "example_k8s_api" {
  type                = "ingress"
  from_port           = 6443
  to_port             = 6443
  protocol            = "tcp"
  security_group_ids = [aws_security_group.example.id]
}


# This code creates an AWS Network ACL and assigns it to a specific 
# VPC and subnet. It also creates a security group and assigns it 
# to the same VPC. The security group includes an inbound rule that 
# allows incoming traffic on port 80 (HTTP) from any IP address. 
# Additionally, it creates an ingress rule that allows incoming traffic 
# on port 6443 (Kubernetes API) from the same security group.



resource "aws_network_acl_rule" "example_inbound_ssh" {
  network_acl_id = aws_network_acl.example.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "example_inbound_https" {
  network_acl_id = aws_network_acl.example.id
  rule_number    = 200
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "example_outbound_all" {
  network_acl_id = aws_network_acl.example.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}



# This code creates two inbound rules and one outbound rule for the ACL. 
# The first inbound rule allows incoming SSH traffic on port 22 from any 
# IP address. The second inbound rule allows incoming HTTPS traffic on 
# port 443 from any IP address. The outbound rule allows all outgoing 
# traffic to any IP address using any protocol.

# You can add as many as needed rules in the similar way as I showed above.

# Please note that in production environment, it is recommended to 
# use specific IP ranges or security groups instead of 0.0.0.0/0 to 
# increase the security.