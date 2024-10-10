output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value       = aws_ecs_cluster.ecs_cluster.name
}

output "ecs_vpc_id" {
  description = "VPC ID for ECS"
  value       = aws_vpc.ecs_vpc.id
}

