
locals {
  common_tags = {
    Name        = "Dormant_S3_Buckets"
    CreatedFrom = "Terraform"
  }
  region_account_id = "${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}"

  # offset is set as 5, because "s3://" is 5 characters long
  substring = "${substr(var.S3PathAthenaQuery, 5, length(var.S3PathAthenaQuery))}"
  s3_arn = format("arn:aws:s3:::%s*", local.substring)
}

output "s3_arn" {
  value = local.s3_arn
}


resource "aws_iam_role" "LambdaIAMRole" {
  name = "Dormant_S3_Buckets-IAM-Role"
  path = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy[1].json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonAthenaFullAccess"]
  inline_policy {
    name = "CFN_Stack_TP_InlinePolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          # "Resource": "*"
          "Resource" : "arn:aws:logs:${local.region_account_id}:log-group:/aws/lambda/Dormant_S3_Buckets-LambdaFunction:*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "sns:Publish"
          ],
          "Resource": "arn:aws:sns:${local.region_account_id}:Dormant_S3_Buckets-SNS-Topic"
        },
        {
          "Effect": "Allow",
          "Action": [
            "s3:GetObject",
          ],
          "Resource": "*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "s3:PutObject"
          ],
          "Resource": local.s3_arn
        }
      ]
    })
  }
  tags = local.common_tags
}

resource "aws_lambda_function" "my_lambda_function" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "dormant_s3_bucket_lambda_code.zip"
  function_name = var.LambdaFunctionName
  description   = "Discover dormant S3 buckets using Athena"
  role          = aws_iam_role.LambdaIAMRole.arn
  handler       = "dormant_s3_bucket_lambda_code.lambda_handler"
  timeout       = 300
  # source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime = "python3.9"
  layers = ["arn:aws:lambda:ap-southeast-1:336392948345:layer:AWSSDKPandas-Python39:7"]
  environment {
    variables = {
      SNS_Topic_Arn = aws_sns_topic.my_SNS_topic.arn
      S3PathAthenaQuery = var.S3PathAthenaQuery
      Limit = var.Limit
      Query = var.Query
    }
  }
  tags = local.common_tags
}

resource "aws_iam_role" "ScheduleIAMRole" {
  name = "Amazon_EventBridge_Scheduler_Dormant_S3_Buckets"
  path = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy[0].json

  inline_policy {
    name = "my_inline_policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          "Effect" : "Allow",
          "Action" : [
            "lambda:InvokeFunction"
          ],
          "Resource" : "arn:aws:lambda:${local.region_account_id}:function:${var.LambdaFunctionName}"
        }
      ]
    })
  }
  tags = local.common_tags
}

resource "aws_scheduler_schedule" "my_scheduler_schedule" {
  name       = "Daily_Invoke_Dormant_S3_Buckets"
  group_name = "default"
  flexible_time_window {
    mode = "OFF"
  }
  schedule_expression = "cron(0 01 * * ? *)"
  schedule_expression_timezone = "Asia/Singapore"
  target {
    arn      = aws_lambda_function.my_lambda_function.arn
    role_arn = aws_iam_role.ScheduleIAMRole.arn
  }
}

resource "aws_sns_topic" "my_SNS_topic" {
  name              = "Dormant_S3_Buckets-SNS-Topic"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "sns_email_target" {
  topic_arn = aws_sns_topic.my_SNS_topic.arn
  protocol  = "email"
  endpoint  = var.Email
}
