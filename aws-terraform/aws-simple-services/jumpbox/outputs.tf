# Create a third file named outputs.tf and paste the following code:

output "ssh_command" {
  value = "ssh -i ${var.jumpbox_private_key_path} ubuntu@${aws_instance.jumpbox.public_ip}"
}

output "mysql_command" {
  value = "mysql -u ${var.rds_username} -p${var.rds_password} -h ${var.rds_host} -P 3306"
}

# In the code above, we define two output variables that will be used later to output the SSH and MySQL commands
