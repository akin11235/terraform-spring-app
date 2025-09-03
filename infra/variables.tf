variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "user1-create-EC2"
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

# =============================================================================
# SECURITY GROUPS
# Virtual firewalls that control traffic to/from resources
# =============================================================================

# # Egress rules 
# =============================================================================


# Ingress
# variable "ingress_rule_protocol" {
#   description = "Protocol for ingress traffic (TCP, UDP, ICMP, or -1 for all)"
#   type        = string
#   default     = "tcp"
# }

# variable "ingress_port_start" {
#   description = "Starting port for ingress rule"
#   type        = number
#   default     = 22
# }

# variable "ingress_port_end" {
#   description = "Ending port for ingress rule"
#   type        = number
#   default     = 22
# }

# variable "ingress_source_cidrs" {
#   description = "CIDR blocks allowed to connect inbound"
#   type        = list(string)
#   default     = ["0.0.0.0/0"] # tighten for security
# }

# variable "egress_rule_protocol" {
#   description = "Protocol for egress traffic"
#   type        = string
#   default     = "-1"
# }

# variable "egress_dest_cidrs" {
#   description = "CIDR blocks to allow egress traffic to"
#   type        = list(string)
#   default     = ["0.0.0.0/0"] # open to the internet
# }

# variable "egress_port_start" {
#   description = "Starting port for egress rule"
#   type        = number
#   default     = 0 # all ports
# }

# variable "egress_port_end" {
#   description = "Ending port for egress rule"
#   type        = number
#   default     = 0 # all ports
# }




# Used for route table (string variable for route tables)
variable "public_route_cidr" {
  description = "Destination CIDR for public route"
  type        = string
  default     = "0.0.0.0/0"
}


# 
variable "vpc_cidr" {
  description = "CIDR block for the entire VPC - defines IP address range"
  type        = string
  default     = "10.0.0.0/16"
  # This provides 65,536 IP addresses (10.0.0.0 to 10.0.255.255)
  # 10.x.x.x is a private IP range as defined in RFC 1918
}


variable "public_subnet_cidr" {
  description = "CIDR block for public subnet - accessible from internet"
  type        = string
  default     = "10.0.10.0/24"
  # Provides 256 IP addresses (10.0.1.0 to 10.0.1.255)
  # Used for resources that need direct internet access (web servers)
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for the second public subnet"
  type        = string
  default     = "10.0.11.0/24"
}


variable "private_subnet_a_cidr" {
  description = "CIDR block for first private subnet - no direct internet access"
  type        = string
  default     = "10.0.20.0/24"
  # Used for backend resources like databases
  # Can access internet through NAT Gateway if needed
}

variable "private_subnet_b_cidr" {
  description = "CIDR block for second private subnet in different AZ"
  type        = string
  default     = "10.0.21.0/24"
  # Required by RDS for Multi-AZ deployment
  # Must be in different availability zone from private_subnet_a
}





variable "db_username" {
  description = "Master username for PostgreSQL database"
  default     = "dbadmin"
}

variable "db_password" {
  description = "Master password for PostgreSQL database"
  type        = string
  sensitive   = true # Prevents password from appearing in logs/console
  default     = "SecurePassword123!"
  # In production, use AWS Secrets Manager or pass via environment variable
}


# =============================================================================
# COMPUTE RESOURCES
# EC2 instances and related infrastructure
# =============================================================================
# ami_id          = "ami-0861f4e788f5069dd"   # Example AMI for us-east-1

variable "instance_name" {
  description = "Tag name for the instance"
  type        = string
  default     = "Ubuntu-app-server"

}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "base_instance_name" {
  description = "Base name for EC2 web servers"
  type        = string
  default     = "web-server"
}



variable "s3_bucket_name" {
  description = "Name of the S3 bucket for app artifacts"
  type        = string
  default     = "artifacts-bucket-spring-app"
}

variable "acm_domain" {
  description = "Domain name for the ACM certificate"
  type        = string
  default     = "example.com" # or your actual domain
}

