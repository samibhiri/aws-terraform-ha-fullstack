
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