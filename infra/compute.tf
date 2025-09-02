# EC2, AMI, ELB, ASG

# =============================================================================
# COMPUTE RESOURCES
# EC2 instances and related infrastructure
# =============================================================================

# SSH Key Pair for accessing EC2 instances
# Generate a new TLS private Key for SSH
resource "tls_private_key" "java_app_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create an AWS key pair using the generated public key
resource "aws_key_pair" "java_app_key_pair" {
  provider   = aws.user1
  key_name   = "java_app_key" # AWS key name
  public_key = tls_private_key.java_app_key.public_key_openssh
}

# Output the key for use in SSH
# output "private_key_pem" {
#   value     = tls_private_key.ec2_tf_training_key.private_key_pem
#   sensitive = true
# }

# Save private key to file (works in both GitHub Actions and locally)
resource "local_file" "private_key_file" {
  content = tls_private_key.java_app_key.private_key_pem
  # filename        = "/home/akin11235/.ssh/tf_keys/ec2_tf_training_key.pem"
  filename        = "${path.module}/java_app_key.pem" # This works in both environments
  file_permission = "0400"
}

# Output the key name for reference
# output "key_pair_name" {
#   value = aws_key_pair.java_app_key_pair.key_name
# }

# Output the EC2 instance public IP for SSH connection
# output "instance_public_ip" {
#   value = aws_instance.app_server.public_ip
# }

# EC2 using the key pair
resource "aws_instance" "app_server" {
  provider        = aws.user1
  ami             = "ami-00ca32bbc84273381"
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.ec2_sg.id]
  key_name        = aws_key_pair.java_app_key_pair.key_name

  # User Data: Install software & prepare EBS
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo amazon-linux-extras enable nginx1 -y
              sudo yum install -y nginx
              sudo systemctl enable nginx
              sudo systemctl start nginx
              # Optionally install certbot for HTTPS
              EOF

  tags = {
    Name = var.instance_name
  }
}


# ----------------------------
# AMI instance from EC2
# ----------------------------
resource "aws_ami_from_instance" "app_server_ami" {
  name                    = "web-server-ami-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  source_instance_id      = aws_instance.app_server.id
  snapshot_without_reboot = true

  tags = {
    Name = "app-server-ami"
  }

  depends_on = [aws_instance.app_server]
}

# ----------------------------
# Launch Template
# ----------------------------
resource "aws_launch_template" "app_server_lt" {
  name_prefix = "app-server-lt-"
  description = "Launch Template for app servers with S3 access"

  # AMI for the app server
  image_id = aws_ami_from_instance.app_server_ami.id

  # Instance type
  instance_type = "t3.micro"

  # SSH key
  key_name = aws_key_pair.java_app_key_pair.key_name

  # Security Groups
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # IAM Role for S3 access
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_s3_profile.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Update packages
    yum update -y

    # Start Nginx
    systemctl enable nginx
    systemctl start nginx

    # Optional: Pull app artifact from S3
    aws s3 cp s3://${var.s3_bucket_name}/myapp.jar /home/ec2-user/
  EOF
  )

  # Tags applied to instances launched from this template
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app-server"
    }
  }

  # Optional: Tag the launch template itself
  tags = {
    Name = "app-server-lt"
  }
}


# # ----------------------------
# # Application Load Balancer
# # ----------------------------
# resource "aws_lb" "app_alb" {
#   name               = "app-alb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.alb_sg.id]
#   subnets            = [aws_subnet.public_subnet.id]  # existing public subnet

#   enable_deletion_protection = false

#   tags = {
#     Name = "app-alb"
#   }
# }

# ----------------------------
# Application Load Balancer (HTTP only)
# ----------------------------
resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet.id] # your existing public subnet

  enable_deletion_protection = false

  tags = {
    Name = "app-alb"
  }
}

# ----------------------------
# Target Group (HTTP)
# ----------------------------
resource "aws_lb_target_group" "app_tg" {
  name        = "app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id # your existing VPC
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  tags = {
    Name = "app-tg"
  }
}


# ----------------------------
# ALB HTTPS Listener
# ----------------------------
# resource "aws_lb_listener" "https_listener" {
#   load_balancer_arn = aws_lb.app_alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = data.aws_acm_certificate.app_cert.arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app_tg.arn
#   }
# }

# # Optional HTTP listener for redirect to HTTPS
# resource "aws_lb_listener" "http_listener" {
#   load_balancer_arn = aws_lb.app_alb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type = "redirect"

#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }



# # ----------------------------
# # ALB HTTPS Listener using dynamic certificate ARN
# # ----------------------------
# resource "aws_lb_listener" "https_listener" {
#   load_balancer_arn = aws_lb.app_alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = data.aws_acm_certificate.app_cert.arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app_tg.arn
#   }
# }

# ----------------------------
# HTTP Listener
# ----------------------------
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ----------------------------
# Auto Scaling Group
# ----------------------------
resource "aws_autoscaling_group" "app_asg" {
  name                = "app-asg"
  max_size            = 3
  min_size            = 1
  desired_capacity    = 2
  vpc_zone_identifier = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id] # existing private subnets

  launch_template {
    id      = aws_launch_template.app_server_lt.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 60

  target_group_arns = [aws_lb_target_group.app_tg.arn]

  # Correct ASG tag syntax
  tag {
    key                 = "Name"
    value               = "app-server"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "Prod"
    propagate_at_launch = true
  }
}