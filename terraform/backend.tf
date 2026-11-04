# --- Latest Ubuntu 24.04 LTS AMI ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (official Ubuntu publisher)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# --- IAM role: lets instances be managed through SSM Session Manager ---
resource "aws_iam_role" "ec2_ssm" {
  name = "${var.project_name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# --- Allow backend instances to read the database secret, and nothing else ---
resource "aws_iam_role_policy" "ec2_read_db_secret" {
  name = "${var.project_name}-read-db-secret"
  role = aws_iam_role.ec2_ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_db_instance.main.master_user_secret[0].secret_arn
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project_name}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}

# --- Launch Template: how each backend instance is built ---
resource "aws_launch_template" "backend" {
  name_prefix   = "${var.project_name}-backend-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.backend.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm.name
  }

  user_data = base64encode(templatefile("${path.module}/templates/backend_user_data.sh.tftpl", {
    repo_url = var.repo_url
    app_port = var.app_port
    db_host  = aws_db_instance.main.address
    db_port  = var.db_port
    db_name  = var.db_name
    db_secret_arn = aws_db_instance.main.master_user_secret[0].secret_arn
    aws_region    = var.aws_region
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-backend" }
  }
}

# --- Auto Scaling Group: keeps 2 to 4 backend instances running ---
resource "aws_autoscaling_group" "backend" {
  name                = "${var.project_name}-backend-asg"
  min_size            = 2
  desired_capacity    = 2
  max_size            = 4
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.backend.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend"
    propagate_at_launch = true
  }
}