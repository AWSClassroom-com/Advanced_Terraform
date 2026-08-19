# modules/app/outputs.tf
# Exposed for the environment wrappers + verification commands in Lab 3.

output "public_ip" {
  description = "Public IP of the EC2 web server. Curl this from the lab EC2 instance to confirm the pipeline deployed correctly."
  value       = aws_instance.web.public_ip
}

output "instance_id" {
  description = "EC2 instance ID — useful for AWS Console deep-links and aws ec2 describe-instances filters."
  value       = aws_instance.web.id
}

output "vpc_id" {
  description = "VPC ID for this environment. Useful when adding peering or shared SGs later."
  value       = aws_vpc.main.id
}

output "api_url" {
  description = "Not applicable for the EC2 module — null here. The bonus serverless module sets this with the API Gateway URL."
  value       = null
}

