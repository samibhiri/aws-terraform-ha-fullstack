
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "db_endpoint" {
  description = "Endpoint of the RDS database"
  value       = aws_db_instance.main.address
}

output "alb_dns_name" {
  description = "Public DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "frontend_url" {
  description = "Public URL of the frontend"
  value       = "http://${aws_instance.frontend.public_ip}"
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the database credentials (managed by RDS)"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}