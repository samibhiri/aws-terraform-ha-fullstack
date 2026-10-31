
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "db_endpoint" {
  description = "Endpoint of the RDS database"
  value       = aws_db_instance.main.address
}