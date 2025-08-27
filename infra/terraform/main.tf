terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }
}

provider "aws" { region = var.region }
locals { prefix = var.project_prefix }

data "aws_caller_identity" "this" {}

# S3 buckets
resource "aws_s3_bucket" "raw" {
  bucket        = "${local.prefix}-raw-${data.aws_caller_identity.this.account_id}"
  force_destroy = true
  tags          = var.tags
}
resource "aws_s3_bucket" "curated" {
  bucket        = "${local.prefix}-curated-${data.aws_caller_identity.this.account_id}"
  force_destroy = true
  tags          = var.tags
}

# Firehose IAM
resource "aws_iam_role" "firehose_role" {
  name = "${local.prefix}-firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "firehose.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "firehose_s3" {
  name = "${local.prefix}-firehose-s3-policy"
  role = aws_iam_role.firehose_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["s3:AbortMultipartUpload","s3:GetBucketLocation","s3:GetObject","s3:ListBucket","s3:ListBucketMultipartUploads","s3:PutObject"],
        Resource = [aws_s3_bucket.raw.arn, "${aws_s3_bucket.raw.arn}/*"] },
      { Effect = "Allow", Action = ["logs:PutLogEvents"], Resource = "*" }
    ]
  })
}

# Firehose → S3 (raw)
resource "aws_kinesis_firehose_delivery_stream" "to_s3" {
  name        = "${local.prefix}-fh-to-s3"
  destination = "extended_s3"
  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.raw.arn
    buffering_size     = var.firehose_buffer_size
    buffering_interval = var.firehose_buffer_interval
    compression_format = "GZIP"
    prefix             = "streaming/!{timestamp:yyyy/MM/dd}/"
    error_output_prefix= "errors/!{firehose:error-output-type}/!{timestamp:yyyy/MM/dd}/"
  }
  tags = var.tags
}

# Glue/Athena catalog
resource "aws_glue_catalog_database" "db" {
  name = "${replace(local.prefix, "-", "_")}_db"
}
resource "aws_iam_role" "glue_role" {
  name = "${local.prefix}-glue-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "glue.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy" "glue_policy" {
  name = "${local.prefix}-glue-policy"
  role = aws_iam_role.glue_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject","s3:PutObject","s3:ListBucket"], Resource = [aws_s3_bucket.raw.arn, "${aws_s3_bucket.raw.arn}/*", aws_s3_bucket.curated.arn, "${aws_s3_bucket.curated.arn}/*"] },
      { Effect = "Allow", Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"], Resource = "*" }
    ]
  })
}
resource "aws_glue_crawler" "raw_crawler" {
  name          = "${local.prefix}-raw-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.db.name
  s3_target { path = "s3://${aws_s3_bucket.raw.bucket}/" }
  configuration = jsonencode({ Version = 1.0, CrawlerOutput = { Partitions = { AddOrUpdateBehavior = "InheritFromTable" } } })
  tags = var.tags
}

# Lambda (API)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../app/lambda"
  output_path = "${path.module}/../../app/lambda.zip"
}
resource "aws_iam_role" "lambda_role" {
  name = "${local.prefix}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${local.prefix}-lambda-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["s3:ListBucket"], Resource = [aws_s3_bucket.curated.arn] },
      { Effect = "Allow", Action = ["s3:GetObject"], Resource = ["${aws_s3_bucket.curated.arn}/*"] },
      { Effect = "Allow", Action = ["s3:PutObject"], Resource = ["${aws_s3_bucket.curated.arn}/*"] },
      { Effect = "Allow", Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"], Resource = "*" }
    ]
  })
}
resource "aws_lambda_function" "api" {
  function_name = "${local.prefix}-api"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.11"
  handler       = "api_handler.handler"
  filename      = data.archive_file.lambda_zip.output_path
  environment { variables = { CURATED_BUCKET = aws_s3_bucket.curated.bucket } }
}

# HTTP API → Lambda
resource "aws_apigatewayv2_api" "http" {
  name          = "${local.prefix}-http-api"
  protocol_type = "HTTP"
  cors_configuration { allow_headers = ["*"], allow_methods = ["GET"], allow_origins = ["*"] }
}
resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}
resource "aws_apigatewayv2_route" "get_data" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /data"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
