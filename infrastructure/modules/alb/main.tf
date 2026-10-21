locals {
  https_enabled = var.certificate_arn != ""
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Public ALB"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each          = toset(var.ingress_cidrs)
  security_group_id = aws_security_group.alb.id
  description       = "HTTP"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each          = local.https_enabled ? toset(var.ingress_cidrs) : toset([])
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}

# ALB may only talk to targets inside the VPC on the container port
resource "aws_vpc_security_group_egress_rule" "to_targets" {
  security_group_id = aws_security_group.alb.id
  description       = "To ECS tasks"
  ip_protocol       = "tcp"
  from_port         = var.container_port
  to_port           = var.container_port
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_lb" "this" {
  name                       = "${var.name}-alb"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = 60
}

resource "aws_lb_target_group" "app" {
  name                 = "${var.name}-tg"
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip" # required for Fargate (awsvpc)
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP listener: forwards when there is no certificate, redirects to HTTPS otherwise
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = local.https_enabled ? "redirect" : "forward"
    target_group_arn = local.https_enabled ? null : aws_lb_target_group.app.arn

    dynamic "redirect" {
      for_each = local.https_enabled ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = local.https_enabled ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
