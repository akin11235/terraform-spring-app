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

# EC2 using the key pair
resource "aws_instance" "app_server" {
  provider        = aws.user1
  # ami             = "ami-00ca32bbc84273381"
  ami             = "ami-0c02fb55956c7d316" 
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.ec2_sg.id]
  key_name        = aws_key_pair.java_app_key_pair.key_name


# User Data: Install software 

  # User Data: Install Nginx & AWS CLI, add sample page
  user_data = <<-EOF
    #!/bin/bash
    # Clean yum cache and update
    sudo yum clean all
    sudo yum update -y

    # Install Nginx if not already installed
    if ! command -v nginx >/dev/null 2>&1; then
      sudo amazon-linux-extras enable nginx1 -y
      sudo yum install -y nginx
    fi

    # Install AWS CLI (if not already installed)
    if ! command -v aws >/dev/null 2>&1; then
      sudo yum install -y awscli
    fi

    # Install Java 17 (Amazon Corretto) if not already installed
  if ! command -v java >/dev/null 2>&1; then
    sudo yum install -y java-17-amazon-corretto
  fi

    # Start and enable Nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx

    
  # Verify Java installation
  java -version

    # Add a sample HTML page
    sudo tee /usr/share/nginx/html/index.html > /dev/null <<'HTML'
<!DOCTYPE html>
<html>
<head>
<title>Test Page</title>
</head>
<body>
<h1>Hello from EC2!</h1>
<p>This page confirms Nginx is running.</p>
</body>
</html>
HTML
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
# -----------------------------
# Launch Template User Data
# -----------------------------
# Enhanced user data script with logging and health check validation

# -----------------------------
# Basic setup with logging
# -----------------------------
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting user data script at $(date)"



# -----------------------------
# Verify Java installation
# -----------------------------
echo "Checking Java version..."
java -version || { echo "Java not found!"; exit 1; }

# -----------------------------
# App setup
# -----------------------------
APP_DIR=/home/ec2-user/app
mkdir -p $APP_DIR
cd $APP_DIR

# Download latest JAR from S3 (optional if you want latest updates)
echo "Downloading JAR from S3..."
if aws s3 cp s3://${var.s3_bucket_name}/demo-0.0.1-SNAPSHOT.jar $APP_DIR/myapp.jar; then
    echo "JAR downloaded successfully"
else
    echo "Failed to download JAR from S3" >&2
    exit 1
fi

# Ensure previous app process is stopped
echo "Stopping any existing app processes..."
pkill -f myapp.jar || true
sleep 5

# Start Spring Boot app with proper JVM settings
echo "Starting Spring Boot application..."
nohup java -jar \
    -Xms256m -Xmx512m \
    -Dserver.port=8080 \
    -Dlogging.level.org.springframework.boot.actuate=DEBUG \
    $APP_DIR/myapp.jar > $APP_DIR/app.log 2>&1 &

APP_PID=$!
echo "Started Spring Boot app with PID: $APP_PID"

# Wait for application to start and verify health endpoint
echo "Waiting for application to be ready..."
    
    # Health check
for i in {1..60}; do
    sleep 10
    echo "Health check attempt $i/60..."
    if curl -f -s http://localhost:8080/actuator/health | grep -q '"status":"UP"'; then
        echo "Application is healthy and ready!"
        break
    fi
done

echo "User data script completed successfully at $(date)"
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
  subnets = [
    aws_subnet.public_subnet.id,
    aws_subnet.public_subnet_2.id
  ]

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
  port        = 8080 # Must match EC2 listening port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "instance"

  health_check {
    path                = "/actuator/health" # Spring Boot health endpoint
    protocol            = "HTTP"
    matcher             = "200-399" 
    interval            = 60
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    port                = "8080"            # Explicitly specify port
  }

  tags = {
    Name = "app-tg"
  }
}


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
  health_check_grace_period = 180 

  target_group_arns = [aws_lb_target_group.app_tg.arn]

  # Correct ASG tag syntax
  tag {
    key                 = "Name"
    value               = "app-server"
    propagate_at_launch = true
  }

}