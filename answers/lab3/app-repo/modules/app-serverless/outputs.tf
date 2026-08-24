# modules/app-serverless/outputs.tf
# Same shape as modules/app/outputs.tf so the wrappers and Lab 3 verification
# commands don't need to know which module is in use — except `public_ip`
# becomes null (Lambda has no IP) and a new `api_url` is added.

output "public_ip" {
  description = "Not applicable for the serverless module — kept on the interface for parity. Use `api_url` instead."
  value       = null
}

output "api_url" {
  description = "HTTP API endpoint. Curl this from the lab EC2 instance to verify the deploy."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "instance_id" {
  description = "Lambda function name — analogous to instance_id for the EC2 module. Useful for `aws lambda invoke` testing."
  value       = aws_lambda_function.greeter.function_name
}

output "vpc_id" {
  description = "Lambda + API Gateway run outside VPC by default. Returns null."
  value       = null
}
