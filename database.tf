# 1. Security Group for PHP Load Balancer
resource "aws_security_group" "php_alb_sg" {
  name        = "${var.environment_name}-php-alb-sg"
  description = "Accept public web requests"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. Security Group for Java Load Balancer
resource "aws_security_group" "java_alb_sg" {
  name        = "${var.environment_name}-java-alb-sg"
  description = "Accept public web requests"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Security Group for Compute Instances (Private Subnets)
resource "aws_security_group" "app_sg" {
  name        = "${var.environment_name}-app-instances-sg"
  description = "Accept traffic only from designated application load balancers"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.php_alb_sg.id]
  }

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.java_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. Security Group for Database Engine
resource "aws_security_group" "rds_sg" {
  name        = "${var.environment_name}-rds-sg"
  description = "Restrict access strictly to application instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. RDS Subnet Group Location
resource "aws_db_subnet_group" "rds_group" {
  name       = "${var.environment_name}-rds-subnet-group"
  subnet_ids = [aws_subnet.isolated_az1.id, aws_subnet.isolated_az2.id]
}

# 6. Primary Master Database (FREE TIER CONFIGURATION)
resource "aws_db_instance" "primary_db" {
  identifier             = "${var.environment_name}-mysql-primary"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro" # 100% Free-tier eligible
  allocated_storage      = 20
  db_name                = "app_production_db"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true

  # COST MANAGEMENT NOTE: Toggled to false for dev/testing validation. 
  # Set to true when moving into enterprise production budgets.
  multi_az               = false 
}