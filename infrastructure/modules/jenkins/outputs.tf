output "instance_id" {
  value = aws_instance.jenkins.id
}

output "admin_secret_name" {
  value = aws_secretsmanager_secret.admin.name
}

output "ssm_port_forward_command" {
  value = "aws ssm start-session --region ${var.region} --target ${aws_instance.jenkins.id} --document-name AWS-StartPortForwardingSession --parameters portNumber=8080,localPortNumber=8080"
}
