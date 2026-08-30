resource "aws_iam_role" "asana_ticket" {
  name = "lambda-asana-ticket-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "asana_ticket_basic" {
  role       = aws_iam_role.asana_ticket.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_secretsmanager_secret" "asana_api_token" {
  name = "asana-api-token-${var.environment}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "asana_api_token" {
  secret_id     = aws_secretsmanager_secret.asana_api_token.id
  secret_string = "REPLACE_ME"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_iam_policy" "asana_tickets_secrets_access" {
  name = "lambda-asana-ticket-secrets-policy-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.asana_api_token.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "asana_tickets_secrets_access" {
  role       = aws_iam_role.asana_ticket.name
  policy_arn = aws_iam_policy.asana_tickets_secrets_access.arn
}

resource "aws_iam_policy" "asana_ticket_correlation_table_access" {
  name = "lambda-asana-ticket-correlation-policy-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "dynamodb:PutItem"
        Resource = var.correlation_table_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "asana_ticket_correlation_table_access" {
  role       = aws_iam_role.asana_ticket.name
  policy_arn = aws_iam_policy.asana_ticket_correlation_table_access.arn
}

resource "aws_sqs_queue" "asana_ticket_dlq" {
  name                    = "lambda-asana-ticket-dlq-${var.environment}"
  sqs_managed_sse_enabled = true
}

resource "aws_iam_role_policy" "asana_ticket_dlq" {
  name = "lambda-asana-ticket-dlq-policy-${var.environment}"
  role = aws_iam_role.asana_ticket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.asana_ticket_dlq.arn
      }
    ]
  })
}

data "aws_kms_key" "lambda_default" {
  key_id = "alias/aws/lambda"
}

resource "aws_lambda_function" "asana_ticket" {
  function_name = var.function_name
  role          = aws_iam_role.asana_ticket.arn
  runtime       = "nodejs24.x"
  handler       = "index.handler"
  s3_bucket     = var.s3_bucket_lambda_artifacts
  s3_key        = var.s3_key
  publish       = true
  timeout       = 10

  environment {
    variables = {
      ASANA_SECRET_ARN       = aws_secretsmanager_secret.asana_api_token.arn
      ASANA_PROJECT_GID      = var.asana_project_gid
      CORRELATION_TABLE_NAME = var.correlation_table_name
    }
  }

  kms_key_arn = data.aws_kms_key.lambda_default.arn

  dead_letter_config {
    target_arn = aws_sqs_queue.asana_ticket_dlq.arn
  }

  tracing_config {
    mode = "Active"
  }

  layers = [var.layer_arn]
}

resource "aws_iam_role_policy_attachment" "asana_ticket_xray" {
  role       = aws_iam_role.asana_ticket.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_lambda_alias" "asana_ticket_live" {
  name             = "live"
  function_name    = aws_lambda_function.asana_ticket.function_name
  function_version = aws_lambda_function.asana_ticket.version
}

