output "raw_bucket"     { value = aws_s3_bucket.raw.bucket }
output "curated_bucket" { value = aws_s3_bucket.curated.bucket }
output "http_api_url"   { value = aws_apigatewayv2_api.http.api_endpoint }
