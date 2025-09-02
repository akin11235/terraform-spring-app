# security groups, IAM roles



# ----------------------------
# IAM role
# ----------------------------
# ----------------------------
# RANDOM ID for IAM role suffix
# ----------------------------
resource "random_id" "role_suffix" {
  byte_length = 2 # 2 bytes → 4 hex characters
}


resource "aws_iam_role" "ec2_s3_access" {
  # Updated to use random_id.role_suffix to avoid conflicts
  name = "EC2-S3-Access-${random_id.role_suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ec2_s3_access_policy" {
  name = "EC2-S3-Access-Policy"
  role = aws_iam_role.ec2_s3_access.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject"]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "EC2-S3-InstanceProfile"
  role = aws_iam_role.ec2_s3_access.name
}




# =============================================================================
# SECURITY GROUPS
# Virtual firewalls that control traffic to/from resources
# =============================================================================

# Security group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg-todo-app"
  description = "ALB security group"
  vpc_id      = aws_vpc.main_vpc.id
}

# Ingress rules for ALB (HTTP/HTTPS from internet)
resource "aws_security_group_rule" "alb_http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_https_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# Outbound rules for ALB (allow all)
resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# Security group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg-todo-app"
  description = "EC2 app server security group"
  vpc_id      = aws_vpc.main_vpc.id
}

# Allow HTTP traffic from ALB for health checks and app
# resource "aws_security_group_rule" "ec2_ingress_from_alb_http" {
#   type                     = "ingress"
#   from_port                = 80
#   to_port                  = 80
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.ec2_sg.id
#   source_security_group_id = aws_security_group.alb_sg.id
# }

# Ingress: only from ALB SG on app port 8080
resource "aws_security_group_rule" "ec2_ingress_from_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ec2_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
}

# Outbound: all (internet via NAT & DB access)
resource "aws_security_group_rule" "ec2_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.ec2_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}


# Security group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg-todo-app"
  description = "RDS PostgreSQL security group"
  vpc_id      = aws_vpc.main_vpc.id
}

# Ingress: only from EC2 SG on PostgreSQL port 5432
resource "aws_security_group_rule" "rds_ingress_from_ec2" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.ec2_sg.id
}

# Outbound: all
resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}
