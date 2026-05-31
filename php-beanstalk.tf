# ==============================================================================
# STACK A: ELASTIC BEANSTALK FOR PHP 8.4
# ==============================================================================

# 1. Define the Elastic Beanstalk Application Container
resource "aws_elastic_beanstalk_application" "php_app" {
  name        = "${var.environment_name}-php-application"
  description = "Production PHP 8.4 Application Stack"
}

# 2. Define the Active Elastic Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "php_env" {
  name                = "dev-php-env"
  application         = aws_elastic_beanstalk_application.php_app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.13.1 running PHP 8.4"

  # Network Configuration
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.main.id
  }
  
  # CHANGED: Put the EC2 instances in the Public Subnets instead of Private
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = "${aws_subnet.public_az1.id},${aws_subnet.public_az2.id}"
  }
  
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = "${aws_subnet.public_az1.id},${aws_subnet.public_az2.id}"
  }

  # MANDATORY FOR PUBLIC SUBNETS: Give instances a public IP to talk to the internet
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "true"
  }

  # ============================================================================
  # MANDATORY IAM SECURITY SETTINGS
  # ============================================================================
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = "aws-elasticbeanstalk-service-role"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "aws-elasticbeanstalk-ec2-role"
  }

  # Environment Variables (Injected Global Parameters for PHP Tablespace)
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_HOST"
    value     = aws_db_instance.primary_db.address 
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_NAME"
    value     = "php_app_db" 
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_USER"
    value     = var.db_username
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_PASSWORD"
    value     = var.db_password
  }
}