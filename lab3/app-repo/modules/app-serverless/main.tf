# modules/app-serverless/main.tf
#
# BONUS module — drop-in replacement for modules/app/. Same input/output
# interface (user_id, environment in; instance_id, vpc_id, public_ip out)
# so swapping `source = "../../modules/app"` for `source = "../../modules/app-serverless"`
# in the wrapper is the entire change required.
#
# What changes: instead of VPC + EC2 + Apache, this deploys Lambda + API Gateway
# HTTP API. No VPC, no EC2 instance-hours, cost ~$0 under free tier (1M
# Lambda requests + 1M API Gateway requests per month free).
#
# Resources created (8):
#   1. aws_iam_role (Lambda execution)
#   2. aws_iam_role_policy_attachment (CloudWatch logs)
#   3. aws_cloudwatch_log_group (Lambda logs, 7-day retention)
#   4. aws_lambda_function
#   5. aws_apigatewayv2_api (HTTP API)
#   6. aws_apigatewayv2_integration (Lambda proxy)
#   7. aws_apigatewayv2_route (GET /)
#   8. aws_apigatewayv2_stage ($default, auto-deploy)
#   + aws_lambda_permission (one-line resource so API Gateway can invoke)

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.js"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.user_id}-${var.environment}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Student     = var.user_id
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.user_id}-${var.environment}-greeter"
  retention_in_days = 7

  tags = {
    Student     = var.user_id
    Environment = var.environment
  }
}

resource "aws_lambda_function" "greeter" {
  function_name    = "${var.user_id}-${var.environment}-greeter"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"

  environment {
    variables = {
      STUDENT_ID  = var.user_id
      ENVIRONMENT = var.environment
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_logs, aws_cloudwatch_log_group.lambda]

  tags = {
    Name        = "${var.user_id}-${var.environment}-greeter"
    Student     = var.user_id
    Environment = var.environment
  }
}

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.user_id}-${var.environment}-api"
  protocol_type = "HTTP"

  tags = {
    Student     = var.user_id
    Environment = var.environment
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.greeter.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Student     = var.user_id
    Environment = var.environment
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.greeter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
