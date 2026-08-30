data "aws_s3_bucket" "recordings" {
  bucket = var.recording_bucket_name
}

resource "aws_iam_role" "recording_transcribe" {
  name = "lambda-asana-recording-transcribe-role-${var.environment}"

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

resource "aws_iam_role_policy_attachment" "recording_transcribe_basic" {
  role       = aws_iam_role.recording_transcribe.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "recording_transcribe_correlation_table_access" {
  name = "lambda-asana-recording-transcribe-correlation-policy-${var.environment}"
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

resource "aws_iam_role_policy_attachment" "recording_transcribe_correlation_table_access" {
  role       = aws_iam_role.recording_transcribe.name
  policy_arn = aws_iam_policy.recording_transcribe_correlation_table_access.arn
}

resource "aws_iam_policy" "recording_transcribe_s3_access" {
  name = "lambda-asana-recording-transcribe-s3-policy-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${data.aws_s3_bucket.recordings.arn}/${var.recording_bucket_prefix}*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${data.aws_s3_bucket.recordings.arn}/transcripts/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "recording_transcribe_s3_access" {
  role       = aws_iam_role.recording_transcribe.name
  policy_arn = aws_iam_policy.recording_transcribe_s3_access.arn
}

resource "aws_iam_policy" "recording_transcribe_transcribe_access" {
  name = "lambda-asana-recording-transcribe-transcribe-policy-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "transcribe:StartTranscriptionJob"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "recording_transcribe_transcribe_access" {
  role       = aws_iam_role.recording_transcribe.name
  policy_arn = aws_iam_policy.recording_transcribe_transcribe_access.arn
}

resource "aws_sqs_queue" "recording_transcribe_dlq" {
  name                    = "lambda-asana-recording-transcribe-dlq-${var.environment}"
  sqs_managed_sse_enabled = true
}

resource "aws_iam_role_policy" "recording_transcribe_dlq" {
  name = "lambda-asana-recording-transcribe-dlq-policy-${var.environment}"
  role = aws_iam_role.recording_transcribe.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.recording_transcribe_dlq.arn
      }
    ]
  })
}

data "aws_kms_key" "lambda_default" {
  key_id = "alias/aws/lambda"
}

resource "aws_lambda_function" "recording_transcribe" {
  function_name = var.function_name
  role          = aws_iam_role.recording_transcribe.arn
  runtime       = "nodejs24.x"
  handler       = "index.handler"
  s3_bucket     = var.s3_bucket_lambda_artifacts
  s3_key        = var.s3_key
  publish       = true
  timeout       = 30

  environment {
    variables = {
      CORRELATION_TABLE_NAME = var.correlation_table_name
      RECORDING_BUCKET_NAME  = var.recording_bucket_name
    }
  }

  kms_key_arn = data.aws_kms_key.lambda_default.arn

  dead_letter_config {
    target_arn = aws_sqs_queue.recording_transcribe_dlq.arn
  }

  tracing_config {
    mode = "Active"
  }

  layers = [var.layer_arn]
}

resource "aws_iam_role_policy_attachment" "recording_transcribe_xray" {
  role       = aws_iam_role.recording_transcribe.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_lambda_permission" "allow_recordings_bucket" {
  statement_id  = "AllowRecordingsBucketInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.recording_transcribe.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.recordings.arn
}

resource "aws_s3_bucket_notification" "recordings" {
  bucket = data.aws_s3_bucket.recordings.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.recording_transcribe.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.recording_bucket_prefix
  }

  depends_on = [aws_lambda_permission.allow_recordings_bucket]
}
