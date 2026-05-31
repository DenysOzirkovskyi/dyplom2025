#!/bin/bash
set -euo pipefail

if [ -z "${APP_IMAGE:-}" ]; then
  REGISTRY="${REGISTRY:-ghcr.io/your-user}"
  IMAGE_NAME="${IMAGE_NAME:-your-repo}"
  IMAGE_TAG="${IMAGE_TAG:-latest}"
  APP_IMAGE="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
fi

export APP_IMAGE
export APP_PORT="${APP_PORT:-80}"

echo "Resolved APP_IMAGE=${APP_IMAGE}"
echo "Resolved APP_PORT=${APP_PORT}"

if [ -n "${GHCR_TOKEN:-}" ] && [ -n "${GHCR_USERNAME:-}" ]; then
  echo "Logging into GitHub Container Registry..."
  echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USERNAME" --password-stdin
else
  echo "GHCR credentials not provided. Skipping docker login."
fi

echo "Pulling the latest images..."
docker compose pull

echo "Starting containers..."
docker compose up -d --remove-orphans

echo "Pruning old unused Docker images..."
docker image prune -f

echo "Deployment finished successfully."
