# # instance_type = "t3.small"
# # instance_name = "Dev-Web-Server"

# # # Security group
# # security_group_name = "dev-web-sg"

# # # Ingress rules
# http_to_port    = 80
# http_from_port  = 80
# https_to_port   = 443
# https_from_port = 443
# ssh_to_port     = 22
# ssh_from_port   = 22

# # ingress_from_port   = 80
# # ingress_to_port     = 80
# ingress_protocol    = "tcp"
# ingress_cidr_blocks = ["0.0.0.0/0"]

# # # Egress rules
# egress_from_port   = 0
# egress_to_port     = 0
# egress_protocol    = "-1"
# # egress_cidr_blocks = ["0.0.0.0/0"]

s3_bucket_name = "artifacts-bucket-1234abcd"
acm_domain     = "mydomain.com"