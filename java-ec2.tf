# ==============================================================================
# STACK B: CUSTOM EC2 AUTO SCALING + ALB FOR JAVA (TOMCAT 11)
# ==============================================================================
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
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

# 2. Target Group (Routes traffic on Tomcat's port 8080 with corrected health path)
resource "aws_lb_target_group" "java_tg" {
  name     = "${var.environment_name}-java-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/dbtest" # <--- FIXED: Tells ALB to look specifically at your servlet
    port                = "8080"
    healthy_threshold   = 2         # Reduced to pass faster
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15        # Checks faster for quicker testing
    matcher             = "200"     # Expects a successful HTTP 200 OK
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

# 4. EC2 Launch Template (Specifies Tomcat machine requirements + Package Installation)
resource "aws_launch_template" "java_template" {
  name_prefix   = "dev-java-template-"
  image_id      = data.aws_ami.amazon_linux_2023.id 
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app_sg.id]
  }


 # FIXED USER DATA: Boots up environment variables, fixes bindings, and provisions Tomcat 11
  user_data = base64encode(<<-EOF
              #!/bin/bash
              # 1. Set DB Environment Variables
              echo "export DB_HOST=${aws_db_instance.primary_db.address}" >> /etc/profile.d/db_env.sh
              echo "export DB_NAME=java_app_db" >> /etc/profile.d/db_env.sh
              echo "export DB_USER=${var.db_username}" >> /etc/profile.d/db_env.sh
              echo "export DB_PASSWORD=${var.db_password}" >> /etc/profile.d/db_env.sh
              source /etc/profile.d/db_env.sh

              # 2. Install Java 17 and Tomcat 11 base packages
              dnf update -y
              dnf install -y java-17-amazon-corretto-devel tomcat

              # 3. Fix Directory Permissions & Structure for GitHub Actions Deployment
              mkdir -p /var/lib/tomcat/webapps/ROOT
              chown -R tomcat:tomcat /var/lib/tomcat/

              # 4. Force Tomcat to bind to all network interfaces (0.0.0.0) instead of just localhost
              SED_PATH="/usr/share/tomcat/conf/server.xml"
              if [ -f "$SED_PATH" ]; then
                sed -i 's/address="127.0.0.1"/address="0.0.0.0"/g' "$SED_PATH"
              fi

              # 5. Start and enable Tomcat service daemon
              systemctl daemon-reload
              systemctl start tomcat
              systemctl enable tomcat
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
  desired_capacity = 1 

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