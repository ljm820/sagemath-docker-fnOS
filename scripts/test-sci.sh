#!/usr/bin/env bash
# =============================================================================
# v3.0 科学环境测试
# 用法: ./scripts/test-sci.sh
# 环境: IMAGE_PREFIX 镜像名前缀 (默认 ljm820/sagemath-fnos)
#       CONTAINER_CMD docker|podman (默认 docker)
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

IMAGE_PREFIX="${IMAGE_PREFIX:-ljm820/sagemath-fnos}"
CONTAINER_CMD="${CONTAINER_CMD:-docker}"
echo ">>> 测试镜像: $IMAGE_PREFIX:debian12-sage9.5 (科学环境, 容器工具=$CONTAINER_CMD)"
IMAGE="$IMAGE_PREFIX:debian12-sage9.5" CONTAINER_CMD="$CONTAINER_CMD" bash "$ROOT/tests/smoke-sci.sh"
echo ">>> 科学环境测试全部完成"
