# Spring Boot application deployment on AWS with Terraform and GitHub Actions
# optional entry point

# =============================================================================
# TERRAFORM CONFIGURATION AND PROVIDER SETUP
# =============================================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.10"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null
  alias   = "user1"
}

# =============================================================================
# DATA SOURCES
# Query existing AWS resources and information
# =============================================================================

# Get list of available availability zones in the current region
data "aws_availability_zones" "available" {
  state = "available" # Only get AZs that are currently available
  # This ensures we don't try to create resources in unavailable AZs
}


# ----------------------------
# Look up ACM certificate by domain name
# ----------------------------
# data "aws_acm_certificate" "app_cert" {
#   domain   = "example.com"       # replace with your domain or test domain
#   statuses = ["ISSUED"]
#   types    = ["AMAZON_ISSUED", "IMPORTED"]
# }

# data "aws_acm_certificate" "app_cert" {
#   domain   = var.acm_domain
#   statuses = ["ISSUED"]
#   types    = ["AMAZON_ISSUED", "IMPORTED"]
# }

data "aws_autoscaling_group" "app_asg_data" {
  name = aws_autoscaling_group.app_asg.name
}

data "aws_instances" "asg_instances" {
  instance_tags = {
    "aws:autoscaling:groupName" = data.aws_autoscaling_group.app_asg_data.name
  }
}

# =============================================================================
# DATABASE RESOURCES
# RDS PostgreSQL instance and related infrastructure
# =============================================================================

# # Subnet group for rds
# resource "aws_db_subnet_group" "private_sn1_tfproject" {
#   name        = "private-sn1-tfproject"
#   description = "Subnet group for RDS instance"

#   # Reference the private subnet
#   subnet_ids = [
#     aws_subnet.private_sn1_tfproject.id,
#     aws_subnet.private_sn2_tfproject.id
#   ]

#   tags = {
#     Name = "private-sn1-tfproject"
#   }
# }

# ----------------------------
# RDS Subnet Group (required for RDS deployment)
# ----------------------------
resource "aws_db_subnet_group" "main" {
  name        = "webapp-db-subnet-group"
  description = "Subnet group for WebApp RDS instance"
  subnet_ids = [
    aws_subnet.private_subnet_a.id,
    aws_subnet.private_subnet_b.id
  ]

  tags = {
    Name = "WebApp DB Subnet Group"
  }
}



# ----------------------------
# PostgreSQL RDS Database Instance
# ----------------------------
# ----------------------------
# PostgreSQL RDS Database Instance
# ----------------------------
resource "aws_db_instance" "postgres" {
  identifier        = "webapp-postgres"
  allocated_storage = 20
  storage_type      = "gp2"
  engine            = "postgres"
  engine_version    = "14.15"
  instance_class    = "db.t3.micro"

  db_name  = "webapp"
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  storage_encrypted   = true
  skip_final_snapshot = true
  deletion_protection = false

  multi_az = false

  tags = {
    Name = "WebApp-PostgreSQL"
  }
}

# # S3 bucket for storing application artifacts
# # ----------------------------
# # Bucket (to be accessed by EC2)
# # ----------------------------
# resource "random_id" "bucket_suffix" {
#   byte_length = 4 # 4 bytes → 8 hex characters
# }

# resource "aws_s3_bucket" "artifacts" {
#   bucket = "artifacts-bucket-${random_id.bucket_suffix.hex}"
# }

#  JUMP SERVER
resource "aws_instance" "jump_server" {
  # ami           = "ami-0c02fb55956c7d316" # Amazon Linux 2 in us-east-1
  ami           = "ami-0c02fb55956c7d316" 
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = aws_key_pair.java_app_key_pair.key_name

  vpc_security_group_ids = [
    aws_security_group.jump_sg.id
  ]

  tags = {
    Name = "jump-server"
  }
}

resource "aws_security_group" "jump_sg" {
  name        = "jump-sg"
  description = "Allow SSH access to jump server"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "SSH from my IP"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["24.141.173.166/32"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

