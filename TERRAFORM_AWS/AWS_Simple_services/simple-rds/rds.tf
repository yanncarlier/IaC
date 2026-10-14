

resource "aws_db_subnet_group" "my_aws_db_subnet_group" {
  name = "main"
  #   subnet_ids = [aws_subnet.frontend.id, aws_subnet.backend.id]
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "My DB subnet group"
  }
}


resource "aws_security_group" "rds" {
  name   = "my-rds-db_rds"
  vpc_id = module.vpc.vpc_id
  #   subnet_ids = module.vpc.private_subnets

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-rds-db_rds"
  }
}

resource "aws_db_parameter_group" "my-rds-db" {
  name   = var.cluster_name
  family = "mysql5.7"

  # parameter {
  #   name  = "log_connections"
  #   value = "1"
  # }

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
}



# start testing dinamic secrets

# resource "random_string" "eks_cluster_master_username" {
#   length  = 8
#   special = false
# }

# resource "random_string" "eks_cluster_master_password" {
#   length           = 16
#   special          = true
#   override_special = "/@\" "
# }

# maybe we can use yet access it's to complex
# resource "aws_secretsmanager_secret" "example" {
#   name = "example"
# }

# end testing dinamic secrets


resource "aws_rds_cluster" "my-rds-db" {
  cluster_identifier = var.cluster_name
  engine             = "aurora-mysql"
  engine_version     = "5.7.mysql_aurora.2.10.2"
  availability_zones = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
  database_name      = var.cluster_name
  master_username    = "root"
  master_password    = "Prototype_Password"

  #   master_username = random_string.eks_cluster_master_username.result
  #   master_password = random_string.eks_cluster_master_password.result

  backup_retention_period = 1
  # preferred_backup_window = "07:00-09:00"
  skip_final_snapshot    = true
  apply_immediately      = true
  deletion_protection    = false
  db_subnet_group_name   = aws_db_subnet_group.my_aws_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # # Grant ROLE_ADMIN on *.* to root user
  # provisioner "local-exec" {
  #   command = "echo 'GRANT ROLE_ADMIN ON *.* TO root@\"%\";' | mysql -h ${aws_rds_cluster.my-rds-db.endpoint} -P 3306 -u root -pPrototype_Password"
  # }
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  count               = 2
  identifier          = "aurora-cluster-demo-${count.index}"
  cluster_identifier  = aws_rds_cluster.my-rds-db.id
  instance_class      = "db.r4.large"
  engine              = aws_rds_cluster.my-rds-db.engine
  engine_version      = aws_rds_cluster.my-rds-db.engine_version
  publicly_accessible = false
  apply_immediately   = true
  # preferred_backup_window = "07:00-09:00"
}













