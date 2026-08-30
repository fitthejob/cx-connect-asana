data "aws_iam_policy_document" "lex_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lexv2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lex_bot" {
  name               = "asana-lex-speech-detection-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.lex_assume_role.json
}

data "aws_iam_policy_document" "lex_bot_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["polly:SynthesizeSpeech"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:log-group:/aws/lex/asana-speech-detection-${var.environment}*"]
  }
}

resource "aws_iam_role_policy" "lex_bot" {
  name   = "asana-lex-speech-detection-permissions-${var.environment}"
  role   = aws_iam_role.lex_bot.id
  policy = data.aws_iam_policy_document.lex_bot_permissions.json
}

resource "aws_lexv2models_bot" "bot" {
  name     = "asana-speech-detection-${var.environment}"
  role_arn = aws_iam_role.lex_bot.arn

  data_privacy {
    child_directed = false
  }

  idle_session_ttl_in_seconds = 300
}

resource "aws_lexv2models_bot_locale" "en_us" {
  bot_id      = aws_lexv2models_bot.bot.id
  bot_version = "DRAFT"
  locale_id   = "en_US"

  n_lu_intent_confidence_threshold = 0.40

  voice_settings {
    voice_id = "Joanna"
    engine   = "neural"
  }
}

resource "aws_lexv2models_intent" "fallback" {
  bot_id                  = aws_lexv2models_bot.bot.id
  bot_version             = "DRAFT"
  locale_id               = aws_lexv2models_bot_locale.en_us.locale_id
  name                    = "FallbackIntent"
  parent_intent_signature = "AMAZON.FallbackIntent"
}

# Single detection-only intent -- deliberately has no slots and its
# matched/unmatched result is never branched on by the flow. Its only
# purpose is to hold the ConnectParticipantWithLexBot action open until
# Lex's own end-of-speech silence timeout fires, at which point every
# transition (intent match, no-match, or timeout) converges on the same
# next action.
resource "aws_lexv2models_intent" "capture" {
  bot_id      = aws_lexv2models_bot.bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "CaptureIntent"

  sample_utterance {
    utterance = "I have an issue"
  }
  sample_utterance {
    utterance = "help"
  }
  sample_utterance {
    utterance = "yes"
  }
}

locals {
  lex_content_hash = md5(jsonencode({
    fallback = {
      parent_intent_signature = aws_lexv2models_intent.fallback.parent_intent_signature
    }
    capture = [for u in aws_lexv2models_intent.capture.sample_utterance : u.utterance]
  }))
}

data "external" "build_bot_locale" {
  program = ["bash", "${path.module}/scripts/build_bot_locale.sh"]

  query = {
    bot_id    = aws_lexv2models_bot.bot.id
    locale_id = aws_lexv2models_bot_locale.en_us.locale_id
  }

  depends_on = [
    aws_lexv2models_intent.fallback,
    aws_lexv2models_intent.capture,
  ]
}

resource "aws_lexv2models_bot_version" "v1" {
  bot_id      = aws_lexv2models_bot.bot.id
  description = "Published version -- content hash ${local.lex_content_hash}"

  locale_specification = {
    (aws_lexv2models_bot_locale.en_us.locale_id) = {
      source_bot_version = "DRAFT"
    }
  }

  depends_on = [data.external.build_bot_locale]

  lifecycle {
    create_before_destroy = true

    replace_triggered_by = [
      aws_lexv2models_intent.fallback,
      aws_lexv2models_intent.capture,
    ]
  }
}

data "external" "bot_alias" {
  program = ["bash", "${path.module}/scripts/create_bot_alias.sh"]

  query = {
    bot_id      = aws_lexv2models_bot.bot.id
    bot_version = aws_lexv2models_bot_version.v1.bot_version
    alias_name  = "live"
    locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  }
}
