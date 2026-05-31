# ==============================================================================
# STACK B: CUSTOM EC2 AUTO SCALING + ALB FOR JAVA (TOMCAT 11)
# ==============================================================================
# Automatically query AWS for the latest official Amazon Linux 2023 AMI
# Dynamically query AWS for the latest official Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    # Use a wildcard (*) so it dynamically accepts any recent release version date build
    values = ["al2023-ami-2023.*-x86_64"] 
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
# 1. Create a Standalone Application Load Balancer for Java Traffic
resource "aws_lb" "java_alb" {
  name               = "${var.environment_name}-java-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.java_alb_sg.id]
  subnets            = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
}

# 2. Target Group (Routes traffic on Tomcat's port 8080)
resource "aws_lb_target_group" "java_tg" {
  name     = "${var.environment_name}-java-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "8080"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

# 3. ALB Listener Routing Rules (Listens on standard port 80 for users)
resource "aws_lb_listener" "java_http" {
  load_balancer_arn = aws_lb.java_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.java_tg.arn
  }
}

# 4. EC2 Launch Template (Specifies Tomcat machine requirements)
resource "aws_launch_template" "java_template" {
  name_prefix   = "dev-java-template-"
  image_id      = data.aws_ami.amazon_linux_2023.id # <-- Changed from hardcoded string to dynamic lookup
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app_sg.id]
  }

  # Injected Global OS Variables via Startup UserData Script for Java Tablespace
  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "export DB_HOST=${aws_db_instance.primary_db.address}" >> /etc/profile.d/db_env.sh
              echo "export DB_NAME=java_app_db" >> /etc/profile.d/db_env.sh
              echo "export DB_USER=${var.db_username}" >> /etc/profile.d/db_env.sh
              echo "export DB_PASSWORD=${var.db_password}" >> /etc/profile.d/db_env.sh
              source /etc/profile.d/db_env.sh
              EOF
  )
}

# 5. Auto Scaling Group spanning multiple Private Subnets
resource "aws_autoscaling_group" "java_asg" {
  name                = "${var.environment_name}-java-asg"
  vpc_zone_identifier = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
  target_group_arns   = [aws_lb_target_group.java_tg.arn]

  min_size         = 1
  max_size         = 3
  desired_capacity = 1 # Single instance boundary to respect Free Tier allowances

  launch_template {
    id      = aws_launch_template.java_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment_name}-java-tomcat"
    propagate_at_launch = true
  }
}