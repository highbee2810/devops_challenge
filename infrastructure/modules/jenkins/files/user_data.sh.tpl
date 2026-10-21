#!/bin/bash
# Bootstraps Jenkins on Amazon Linux 2023 (runs once via cloud-init).
set -euxo pipefail
exec > >(tee /var/log/jenkins-bootstrap.log) 2>&1

dnf install -y docker jq
systemctl enable --now docker

mkdir -p /opt/jenkins/build /opt/jenkins/secrets
echo '${dockerfile_b64}' | base64 -d > /opt/jenkins/build/Dockerfile
echo '${plugins_b64}'    | base64 -d > /opt/jenkins/build/plugins.txt
echo '${casc_b64}'       | base64 -d > /opt/jenkins/build/casc.yaml

# Admin password comes from Secrets Manager (instance role) - never from user-data or the repo.
aws secretsmanager get-secret-value --region ${region} --secret-id ${secret_id} \
  --query SecretString --output text > /opt/jenkins/secrets/JENKINS_ADMIN_PASSWORD
chown -R 1000:1000 /opt/jenkins/secrets
chmod 0500 /opt/jenkins/secrets
chmod 0400 /opt/jenkins/secrets/JENKINS_ADMIN_PASSWORD

docker build -t jenkins-casc:latest /opt/jenkins/build
docker volume create jenkins_home

docker run -d --name jenkins --restart unless-stopped \
  -p 127.0.0.1:8080:8080 \
  --group-add "$(stat -c %g /var/run/docker.sock)" \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /opt/jenkins/secrets:/run/secrets:ro \
  -e AWS_REGION=${region} \
  -e REPO_URL=${repo_url} \
  -e ECR_REPO_URL=${ecr_repo_url} \
  -e ECS_CLUSTER=${ecs_cluster} \
  -e ECS_SERVICE=${ecs_service} \
  -e APP_URL=${app_url} \
  -e MIN_TASKS=${min_tasks} \
  --log-driver awslogs \
  --log-opt awslogs-region=${region} \
  --log-opt awslogs-group=${log_group} \
  --log-opt awslogs-stream=controller \
  jenkins-casc:latest
