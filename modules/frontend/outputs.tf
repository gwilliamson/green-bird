output "cloudfront_url" {
  value       = aws_cloudfront_distribution.frontend.domain_name
  description = "CloudFront URL for the React frontend"
}
