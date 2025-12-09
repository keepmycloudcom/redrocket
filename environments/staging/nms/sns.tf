resource "aws_sns_topic" "pipeline_notifications" {
  name = "${local.basename}-codepipeline-ExecutionChanges"
  tags = local.base_tags
}

data "aws_iam_policy_document" "pipeline_notifications_access" {
  statement {
    actions = ["sns:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.pipeline_notifications.arn]
  }
}

resource "aws_sns_topic_policy" "pipeline_notifications" {
  arn    = aws_sns_topic.pipeline_notifications.arn
  policy = data.aws_iam_policy_document.pipeline_notifications_access.json
}

resource "aws_cloudwatch_event_rule" "pipeline_notifications" {
  name           = "${local.basename}-codepipeline-ExecutionChanges"
  description    = "This rule routes events from CodePipeline to an SNS topic and transforms them from JSON to be readable"

  event_pattern = jsonencode({
    detail = {
      state = ["SUCCEEDED", "FAILED"]
      pipeline = [{
        prefix = "${local.basename}"
      }]
    }
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    source      = ["aws.codepipeline"]
  })
  tags = local.base_tags
}
resource "aws_cloudwatch_event_target" "pipeline_notifications_sns" {
  rule      = aws_cloudwatch_event_rule.pipeline_notifications.name
  arn       = aws_sns_topic.pipeline_notifications.arn

  input_transformer {
    input_paths = {
      region    = "$.region"
      execution = "$.detail.execution-id"
      pipeline  = "$.detail.pipeline"
      state     = "$.detail.state"
    }

    input_template = "\"The '<pipeline>' pipeline has changed to <state> state with execution ID <execution>. For more information, go to: https://<region>.console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/view?region=<region> \""
  }
}
