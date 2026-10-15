# # for future outputs reference 
# # https://github.com/terraform-aws-modules/terraform-aws-rds-aurora/blob/master/outputs.tf




output "rds_port" {
  description = "RDS instance port"
  value       = aws_rds_cluster.my-rds-db.port
  sensitive   = true
}
output "rds_username" {
  description = "RDS instance root username"
  value       = aws_rds_cluster.my-rds-db.master_username
  sensitive   = true
}






################################################################################
# DB Subnet Group
################################################################################

# output "db_subnet_group_name" {
#   description = "The db subnet group name"
#   value       = local.db_subnet_group_name
# }

################################################################################
# Cluster
################################################################################

output "cluster_arn" {
  description = "Amazon Resource Name (ARN) of cluster"
  value       = try(aws_rds_cluster.my-rds-db.arn, "")
}

output "cluster_id" {
  description = "The RDS Cluster Identifier"
  value       = try(aws_rds_cluster.my-rds-db.id, "")
}

output "cluster_resource_id" {
  description = "The RDS Cluster Resource ID"
  value       = try(aws_rds_cluster.my-rds-db.cluster_resource_id, "")
}

output "cluster_members" {
  description = "List of RDS Instances that are a part of this cluster"
  value       = try(aws_rds_cluster.my-rds-db.cluster_members, "")
}

output "cluster_endpoint" {
  description = "Writer endpoint for the cluster"
  value       = try(aws_rds_cluster.my-rds-db.endpoint, "")
}

output "cluster_reader_endpoint" {
  description = "A read-only endpoint for the cluster, automatically load-balanced across replicas"
  value       = try(aws_rds_cluster.my-rds-db.reader_endpoint, "")
}

# output "cluster_engine_version_actual" {
#   description = "The running version of the cluster database"
#   value       = try(aws_rds_cluster.my-rds-db.engine_version_actual, "")
# }

# # database_name is not set on `aws_rds_cluster` resource if it was not specified, so can't be used in output
# output "cluster_database_name" {
#   description = "Name for an automatically created database on cluster creation"
#   value       = var.database_name
# }

output "cluster_port" {
  description = "The database port"
  value       = try(aws_rds_cluster.my-rds-db.port, "")
}

output "cluster_master_password" {
  description = "The database master password"
  value       = try(aws_rds_cluster.my-rds-db.master_password, "")
  sensitive   = true
}

output "cluster_master_username" {
  description = "The database master username"
  value       = try(aws_rds_cluster.my-rds-db.master_username, "")
  sensitive   = true
}

output "cluster_hosted_zone_id" {
  description = "The Route53 Hosted Zone ID of the endpoint"
  value       = try(aws_rds_cluster.my-rds-db.hosted_zone_id, "")
}

################################################################################
# Cluster Instance(s)
################################################################################

# output "cluster_instances" {
#   description = "A map of cluster instances and their attributes"
#   value       = aws_rds_cluster_instance.this
# }

################################################################################
# Cluster Endpoint(s)
################################################################################

# output "additional_cluster_endpoints" {
#   description = "A map of additional cluster endpoints and their attributes"
#   value       = aws_rds_cluster_endpoint.this
# }

################################################################################
# Cluster IAM Roles
################################################################################

# output "cluster_role_associations" {
#   description = "A map of IAM roles associated with the cluster and their attributes"
#   value       = aws_rds_cluster_role_association.this
# }

################################################################################
# Enhanced Monitoring
################################################################################

# output "enhanced_monitoring_iam_role_name" {
#   description = "The name of the enhanced monitoring role"
#   value       = try(aws_iam_role.rds_enhanced_monitoring[0].name, "")
# }

# output "enhanced_monitoring_iam_role_arn" {
#   description = "The Amazon Resource Name (ARN) specifying the enhanced monitoring role"
#   value       = try(aws_iam_role.rds_enhanced_monitoring[0].arn, "")
# }

# output "enhanced_monitoring_iam_role_unique_id" {
#   description = "Stable and unique string identifying the enhanced monitoring role"
#   value       = try(aws_iam_role.rds_enhanced_monitoring[0].unique_id, "")
# }

################################################################################
# Security Group
################################################################################

# output "security_group_id" {
#   description = "The security group ID of the cluster"
#   value       = try(aws_security_group.my-rds-db.id, "")
# }

################################################################################
# Cluster Parameter Group
################################################################################

# output "db_cluster_parameter_group_arn" {
#   description = "The ARN of the DB cluster parameter group created"
#   value       = try(aws_rds_cluster_parameter_group.my-rds-db.arn, "")
# }

# output "db_cluster_parameter_group_id" {
#   description = "The ID of the DB cluster parameter group created"
#   value       = try(aws_rds_cluster_parameter_group.my-rds-db.id, "")
# }

################################################################################
# DB Parameter Group
################################################################################

output "db_parameter_group_arn" {
  description = "The ARN of the DB parameter group created"
  value       = try(aws_db_parameter_group.my-rds-db.arn, "")
}

output "db_parameter_group_id" {
  description = "The ID of the DB parameter group created"
  value       = try(aws_db_parameter_group.my-rds-db.id, "")
}