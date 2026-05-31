# 1. Dynamically find the official Elastic Beanstalk Hosted Zone ID for your active AWS region
data "aws_elastic_beanstalk_hosted_zone" "current" {}

# 2. Tell AWS to CREATE a brand new Hosted Zone for your GoDaddy domain
resource "aws_route53_zone" "primary" {
  name    = "sidaaruran.com"
  comment = "Managed by Terraform Infrastructure Pipeline"
}

# 3. DNS Record for the PHP Application (Elastic Beanstalk)
resource "aws_route53_record" "php_dns" {
  zone_id = aws_route53_zone.primary.zone_id 
  name    = "php.${aws_route53_zone.primary.name}" 
  type    = "A"

  alias {
    name                   = aws_elastic_beanstalk_environment.php_env.cname
    zone_id                = data.aws_elastic_beanstalk_hosted_zone.current.id # <-- Changed to dynamic lookup!
    evaluate_target_health = true
  }
}

# 4. DNS Record for the Java Application (Custom ALB)
resource "aws_route53_record" "java_dns" {
  zone_id = aws_route53_zone.primary.zone_id 
  name    = "java.${aws_route53_zone.primary.name}" 
  type    = "A"

  alias {
    name                   = aws_lb.java_alb.dns_name
    zone_id                = aws_lb.java_alb.zone_id
    evaluate_target_health = true
  }
}