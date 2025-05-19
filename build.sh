#!/bin/bash
set -e

# Set resource limits
export DOCKER_BUILDKIT_MEMORY=90g
export DOCKER_BUILDKIT_SWAP=-1

echo "Starting build with memory limit: $DOCKER_BUILDKIT_MEMORY"
echo "Using bake file: docker-bake.hcl"

# Run buildx bake
docker buildx bake -f docker-bake.hcl

echo "Build completed successfully" 