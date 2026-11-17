output "web_acl_arn" {
  description = "ARN of the regional Web ACL. Associate it with an ALB, API Gateway, or other regional resource."
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_id" {
  description = "ID of the regional Web ACL."
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_name" {
  description = "Name of the regional Web ACL."
  value       = aws_wafv2_web_acl.this.name
}
