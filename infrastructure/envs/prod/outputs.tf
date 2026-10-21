output "app_url" {
  value = "${local.app_scheme}://${module.alb.dns_name}"
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecs_cluster" {
  value = module.ecs.cluster_name
}

output "ecs_service" {
  value = module.ecs.service_name
}

output "jenkins_instance_id" {
  value = module.jenkins.instance_id
}

output "jenkins_port_forward_command" {
  description = "Run this, then open http://localhost:8080"
  value       = module.jenkins.ssm_port_forward_command
}

output "jenkins_admin_password_command" {
  value = "aws secretsmanager get-secret-value --region ${var.region} --secret-id ${module.jenkins.admin_secret_name} --query SecretString --output text"
}

output "dashboard_name" {
  value = module.monitoring.dashboard_name
}
