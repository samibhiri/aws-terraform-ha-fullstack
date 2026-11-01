resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  user_data = templatefile("${path.module}/templates/frontend_user_data.sh.tftpl", {
    repo_url     = var.repo_url
    alb_dns_name = aws_lb.main.dns_name
  })
  user_data_replace_on_change = true

  tags = { Name = "${var.project_name}-frontend" }
}