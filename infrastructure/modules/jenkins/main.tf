data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------- Admin credential ----------
resource "random_password" "admin" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "admin" {
  name                    = "${var.name}/jenkins-admin-password"
  recovery_window_in_days = var.secret_recovery_window_days
}

resource "aws_secretsmanager_secret_version" "admin" {
  secret_id     = aws_secretsmanager_secret.admin.id
  secret_string = random_password.admin.result
}

resource "aws_cloudwatch_log_group" "jenkins" {
  name              = "/jenkins/${var.name}"
  retention_in_days = var.log_retention_days
}

# ---------- Network: no inbound at all; access is through SSM Session Manager ----------
resource "aws_security_group" "jenkins" {
  name        = "${var.name}-jenkins-sg"
  description = "Jenkins: no inbound, outbound only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-jenkins-sg" }
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.jenkins.id
  description       = "Outbound via NAT (GitHub, ECR, AWS APIs, Docker Hub)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------- IAM (least privilege, no static AWS keys anywhere) ----------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "${var.name}-jenkins"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "jenkins" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [var.ecr_repository_arn]
  }

  statement {
    sid       = "EcsDeployService"
    actions   = ["ecs:DescribeServices", "ecs:UpdateService"]
    resources = [var.ecs_service_arn]
  }

  statement {
    sid       = "EcsTaskDefinitions"
    actions   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
    resources = ["*"] # these two actions do not support resource-level permissions
  }

  statement {
    sid       = "PassTaskRoles"
    actions   = ["iam:PassRole"]
    resources = var.ecs_role_arns
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid       = "ReadAdminSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.admin.arn]
  }

  statement {
    sid       = "ContainerLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.jenkins.arn}:*"]
  }
}

resource "aws_iam_role_policy" "jenkins" {
  name   = "jenkins-deploy"
  role   = aws_iam_role.jenkins.id
  policy = data.aws_iam_policy_document.jenkins.json
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.name}-jenkins"
  role = aws_iam_role.jenkins.name
}

# ---------- Instance ----------
resource "aws_instance" "jenkins" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  associate_public_ip_address = false
  monitoring                  = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2          # lets the Jenkins container reach the instance role
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_gb
    encrypted   = true
  }

  user_data = templatefile("${path.module}/files/user_data.sh.tpl", {
    region         = var.region
    secret_id      = aws_secretsmanager_secret.admin.name
    repo_url       = var.repo_url
    ecr_repo_url   = var.ecr_repository_url
    ecs_cluster    = var.ecs_cluster_name
    ecs_service    = var.ecs_service_name
    app_url        = var.app_url
    min_tasks      = var.min_tasks
    log_group      = aws_cloudwatch_log_group.jenkins.name
    dockerfile_b64 = filebase64("${path.module}/files/Dockerfile")
    plugins_b64    = filebase64("${path.module}/files/plugins.txt")
    casc_b64       = filebase64("${path.module}/files/casc.yaml")
  })

  tags = { Name = "${var.name}-jenkins" }

  # Jenkins is rebuilt from code (`terraform taint`) rather than mutated in place.
  lifecycle {
    ignore_changes = [ami, user_data]
  }

  depends_on = [aws_iam_role_policy.jenkins, aws_iam_role_policy_attachment.ssm]
}
