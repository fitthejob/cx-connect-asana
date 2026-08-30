resource "aws_iam_role" "transcript_update" {
  name = "lambda-asana-transcript-update-role-${var.environment}"

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

resource "aws_iam_role_policy_attachment" "transcript_update_basic" {
  role       = aws_iam_role.transcript_update.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "transcript_update_correlation_table_access" {
  name = "lambda-asana-transcript-update-correlation-policy-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "dynamodb:GetItem"
        Resource = var.correlation_table_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "transcript_update_correlation_table_access" {
  role       = aws_iam_role.transcript_update.name
  policy_arn = aws_iam_policy.transcript_update_correlation_table_access.arn
}

resource "aws_iam_policy" "transcript_update_s3_access" {
  name = "lambda-asana-transcript-update-s3-policy-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.recording_bucket_name}/transcripts/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "transcript_update_s3_access" {
  role       = aws_iam_role.transcript_update.name
  policy_arn = aws_iam_policy.transcript_update_s3_access.arn
}

resource "aws_iam_policy" "transcript_update_secrets_access" {
  name = "lambda-asana-transcript-update-secrets-policy-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.asana_secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "transcript_update_secrets_access" {
  role       = aws_iam_role.transcript_update.name
  policy_arn = aws_iam_policy.transcript_update_secrets_access.arn
}

resource "aws_sqs_queue" "transcript_update_dlq" {
  name                    = "lambda-asana-transcript-update-dlq-${var.environment}"
  sqs_managed_sse_enabled = true
}

resource "aws_iam_role_policy" "transcript_update_dlq" {
  name = "lambda-asana-transcript-update-dlq-policy-${var.environment}"
  role = aws_iam_role.transcript_update.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.transcript_update_dlq.arn
      }
    ]
  })
}

data "aws_kms_key" "lambda_default" {
  key_id = "alias/aws/lambda"
}

resource "aws_lambda_function" "transcript_update" {
  function_name = var.function_name
  role          = aws_iam_role.transcript_update.arn
  runtime       = "nodejs24.x"
  handler       = "index.handler"
  s3_bucket     = var.s3_bucket_lambda_artifacts
  s3_key        = var.s3_key
  publish       = true
  timeout       = 15

  environment {
    variables = {
      CORRELATION_TABLE_NAME = var.correlation_table_name
      RECORDING_BUCKET_NAME  = var.recording_bucket_name
      ASANA_SECRET_ARN       = var.asana_secret_arn
    }
  }

  kms_key_arn = data.aws_kms_key.lambda_default.arn

  dead_letter_config {
    target_arn = aws_sqs_queue.transcript_update_dlq.arn
  }

  tracing_config {
    mode = "Active"
  }

  layers = [var.layer_arn]
}

resource "aws_iam_role_policy_attachment" "transcript_update_xray" {
  role       = aws_iam_role.transcript_update.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_lambda_alias" "transcript_update_live" {
  name             = "live"
  function_name    = aws_lambda_function.transcript_update.function_name
  function_version = aws_lambda_function.transcript_update.version
}

# Native Amazon Transcribe EventBridge event -- delivered to the account's
# default event bus (no event_bus_name set), same pattern as
# connect-terraform's aws_cloudwatch_event_rule.native_contact_events.
resource "aws_cloudwatch_event_rule" "transcribe_job_completed" {
  name = "lambda-asana-transcribe-job-completed-${var.environment}"

  event_pattern = jsonencode({
    source      = ["aws.transcribe"]
    detail-type = ["Transcribe Job State Change"]
    detail = {
      TranscriptionJobStatus = ["COMPLETED"]
    }
  })
}

resource "aws_sqs_queue" "transcribe_job_completed_durable" {
  name                    = "lambda-asana-transcribe-job-completed-durable-${var.environment}"
  sqs_managed_sse_enabled = true
}

resource "aws_cloudwatch_event_target" "transcribe_job_completed_sqs" {
  rule      = aws_cloudwatch_event_rule.transcribe_job_completed.name
  target_id = "durable-sqs"
  arn       = aws_sqs_queue.transcribe_job_completed_durable.arn
}

resource "aws_sqs_queue_policy" "transcribe_job_completed_durable" {
  queue_url = aws_sqs_queue.transcribe_job_completed_durable.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.transcribe_job_completed_durable.arn
        Condition = {
          ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.transcribe_job_completed.arn }
        }
      }
    ]
  })
}

resource "aws_sqs_queue" "transcribe_job_completed_lambda_target_dlq" {
  name                    = "lambda-asana-transcribe-job-completed-dlq-${var.environment}"
  sqs_managed_sse_enabled = true
}

resource "aws_sqs_queue_policy" "transcribe_job_completed_lambda_target_dlq" {
  queue_url = aws_sqs_queue.transcribe_job_completed_lambda_target_dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.transcribe_job_completed_lambda_target_dlq.arn
        Condition = {
          ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.transcribe_job_completed.arn }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "transcribe_job_completed_lambda" {
  rule      = aws_cloudwatch_event_rule.transcribe_job_completed.name
  target_id = "lambda-subscriber"
  arn       = aws_lambda_alias.transcript_update_live.arn

  dead_letter_config {
    arn = aws_sqs_queue.transcribe_job_completed_lambda_target_dlq.arn
  }

  retry_policy {
    maximum_retry_attempts       = 3
    maximum_event_age_in_seconds = 300
  }
}

resource "aws_lambda_permission" "allow_eventbridge_transcribe_job_completed" {
  statement_id  = "AllowEventBridge-transcribe-job-completed"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transcript_update.function_name
  qualifier     = aws_lambda_alias.transcript_update_live.name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.transcribe_job_completed.arn
}

resource "aws_cloudwatch_metric_alarm" "transcribe_job_completed_durable_dlq_depth" {
  alarm_name          = "lambda-asana-transcribe-job-completed-durable-dlq-depth-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.transcribe_job_completed_durable.name
  }
}

resource "aws_cloudwatch_metric_alarm" "transcribe_job_completed_lambda_dlq_depth" {
  alarm_name          = "lambda-asana-transcribe-job-completed-lambda-dlq-depth-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.transcribe_job_completed_lambda_target_dlq.name
  }
}
