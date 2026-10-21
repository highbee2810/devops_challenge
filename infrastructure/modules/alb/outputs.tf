output "security_group_id" {
  value = aws_security_group.alb.id
}

output "dns_name" {
  value = aws_lb.this.dns_name
}

output "arn_suffix" {
  value = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.app.arn_suffix
}

# Exposed through an output so consumers (the ECS service) implicitly wait for the listeners.
output "target_group_arn" {
  value      = aws_lb_target_group.app.arn
  depends_on = [aws_lb_listener.http, aws_lb_listener.https]
}
