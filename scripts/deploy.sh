#!/usr/bin/env bash
# Deploys IMAGE_URI to the ECS service by registering a new task-definition revision.
# Fails (non-zero) if ECS rolls the deployment back, so the pipeline never reports a false success.
set -euo pipefail

: "${AWS_REGION:?}" "${ECS_CLUSTER:?}" "${ECS_SERVICE:?}" "${IMAGE_URI:?}"
MIN_TASKS="${MIN_TASKS:-2}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"

svc() { aws ecs describe-services --region "$AWS_REGION" --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query "$1" --output text; }

CURRENT_TD=$(svc 'services[0].taskDefinition')
DESIRED=$(svc 'services[0].desiredCount')
[ "$DESIRED" -lt "$MIN_TASKS" ] && DESIRED="$MIN_TASKS"   # first run: service starts at 0 tasks

echo ">> Current task definition: $CURRENT_TD"

NEW_TD_JSON=$(aws ecs describe-task-definition --region "$AWS_REGION" --task-definition "$CURRENT_TD" \
  --query taskDefinition --output json |
  jq --arg img "$IMAGE_URI" '
    del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities,
        .registeredAt, .registeredBy, .deregisteredAt)
    | .containerDefinitions[0].image = $img')

NEW_TD=$(aws ecs register-task-definition --region "$AWS_REGION" --cli-input-json "$NEW_TD_JSON" \
  --query taskDefinition.taskDefinitionArn --output text)
echo ">> Registered: $NEW_TD"

aws ecs update-service --region "$AWS_REGION" --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE" \
  --task-definition "$NEW_TD" --desired-count "$DESIRED" >/dev/null
echo ">> Deployment started, waiting for rollout (timeout ${TIMEOUT_SECONDS}s)"

deadline=$((SECONDS + TIMEOUT_SECONDS))
while [ "$SECONDS" -lt "$deadline" ]; do
  STATE=$(svc "services[0].deployments[?taskDefinition=='${NEW_TD}'].rolloutState | [0]")
  echo "   rolloutState=${STATE}"
  case "$STATE" in
    COMPLETED) echo ">> Deployment succeeded"; exit 0 ;;
    FAILED)    echo "!! Deployment failed; ECS circuit breaker rolled back to the previous revision"; exit 1 ;;
  esac
  sleep 15
done

echo "!! Timed out waiting for the deployment"
exit 1
