# terraform create a aws ubuntu small instance to use as a jumpbox and connect to an RDS mysql database
# To create an AWS Ubuntu small instance using Terraform and use it as a jumpbox to connect to an RDS MySQL database, you can follow the below steps:
# Create a new directory to hold your Terraform files and navigate to that directory.
# Create a new file named main.tf and paste the following code:



provider "aws" {
  region = "us-west-2"
}

resource "aws_instance" "jumpbox" {
  ami             = "ami-0c55b159cbfafe1f0"
  instance_type   = "t2.micro"
  key_name        = "your_key_name"
  security_groups = ["default"]
  tags = {
    Name = "jumpbox"
  }
}

resource "aws_security_group" "jumpbox_sg" {
  name_prefix = "jumpbox_sg_"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "jumpbox_outbound" {
  security_group_id = aws_security_group.jumpbox_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "jumpbox_inbound" {
  security_group_id        = aws_security_group.jumpbox_sg.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  cidr_blocks              = ["0.0.0.0/0"]
  source_security_group_id = aws_security_group.jumpbox_sg.id
}

output "jumpbox_public_ip" {
  value = aws_instance.jumpbox.public_ip
}

# In the code above, we first specify the AWS region we want to use, which in this case is "us-west-2". Then we define an AWS instance resource named "jumpbox" using the Ubuntu AMI and the t2.micro instance type. We also specify the key name, security group, and tags for the instance.
# Next, we create an AWS security group resource named "jumpbox_sg", which allows inbound SSH traffic from any IP address. We also create two security group rules, one for inbound traffic and another for outbound traffic.
# Finally, we create an output variable named "jumpbox_public_ip", which outputs the public IP address of the jumpbox instance.







