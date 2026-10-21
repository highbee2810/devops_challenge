locals {
  name           = "${var.project}-${var.environment}"
  container_port = 3000
  app_scheme     = var.certificate_arn == "" ? "http" : "https"
}

module "network" {
  source             = "../../modules/network"
  name               = local.name
  vpc_cidr           = var.vpc_cidr
  az_count           = 2
  single_nat_gateway = var.single_nat_gateway
}

module "ecr" {
  source = "../../modules/ecr"
  name   = local.name

  force_delete = var.allow_destroy
}

module "alb" {
  source            = "../../modules/alb"
  name              = local.name
  vpc_id            = module.network.vpc_id
  vpc_cidr          = module.network.vpc_cidr
  public_subnet_ids = module.network.public_subnet_ids
  container_port    = local.container_port
  certificate_arn   = var.certificate_arn
  ingress_cidrs     = var.alb_ingress_cidrs

  enable_deletion_protection = !var.allow_destroy
}

module "ecs" {
  source                = "../../modules/ecs"
  name                  = local.name
  region                = var.region
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arn
  ecr_repository_url    = module.ecr.repository_url
  container_port        = local.container_port
  min_capacity          = var.min_tasks
  max_capacity          = var.max_tasks
}

module "jenkins" {
  source             = "../../modules/jenkins"
  name               = local.name
  region             = var.region
  vpc_id             = module.network.vpc_id
  subnet_id          = module.network.private_subnet_ids[0]
  instance_type      = var.jenkins_instance_type
  repo_url           = var.repo_url
  ecr_repository_url = module.ecr.repository_url
  ecr_repository_arn = module.ecr.repository_arn
  ecs_cluster_name   = module.ecs.cluster_name
  ecs_service_name   = module.ecs.service_name
  ecs_service_arn    = module.ecs.service_arn
  ecs_role_arns      = [module.ecs.task_role_arn, module.ecs.execution_role_arn]
  app_url            = "${local.app_scheme}://${module.alb.dns_name}"
  min_tasks          = var.min_tasks

  secret_recovery_window_days = var.allow_destroy ? 0 : 7
}

module "monitoring" {
  source                  = "../../modules/monitoring"
  name                    = local.name
  region                  = var.region
  alarm_email             = var.alarm_email
  alb_arn_suffix          = module.alb.arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  cluster_name            = module.ecs.cluster_name
  service_name            = module.ecs.service_name
  app_log_group_name      = module.ecs.log_group_name
  min_tasks               = var.min_tasks
  jenkins_instance_id     = module.jenkins.instance_id
}
