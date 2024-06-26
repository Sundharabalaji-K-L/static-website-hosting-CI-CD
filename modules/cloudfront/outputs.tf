output "cloudfront_arn" {
    value = aws_cloudfront_distribution.s3_distribution.arn
  
}

output "cloudfront_id" {
    value = aws_cloudfront_distribution.s3_distribution.id
  
}

output "cloudfront_domain_name" {
    value = aws_cloudfront_distribution.s3_distribution.domain_name
  
}

output "cloudfront_zone_id" {
    value = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
  
}
