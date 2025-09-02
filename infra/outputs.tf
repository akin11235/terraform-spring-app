# ==============================
# Outputs
# ==============================
output "key_pair_name" {
  value = aws_key_pair.java_app_key_pair.key_name
}

# output "private_key_path" {
#   value     = local_file.private_key_file.filename
#   sensitive = true
# }

# Output the EC2 instance public IP for SSH connection
output "instance_public_ip" {
  value = aws_instance.app_server.public_ip
}


output "alb_dns_name" {
  value = aws_lb.app_alb.dns_name
}

output "asg_instance_ids" {
  value = data.aws_instances.asg_instances.ids
}

output "s3_bucket_name" {
  value = var.s3_bucket_name
}