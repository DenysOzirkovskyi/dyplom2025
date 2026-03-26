#!/bin/bash
set -e

echo "Logging into GitHub Container Registry..."
echo "$GH_PAT" | docker login "$REGISTRY" -u "$GH_ACTOR" --password-stdin

echo "Pulling the latest image for web..."
docker compose pull web

echo "Starting deployment..."
docker compose up -d --remove-orphans

echo "Pruning old unused Docker images..."
docker image prune -af

echo "Deployment finished successfully!"
