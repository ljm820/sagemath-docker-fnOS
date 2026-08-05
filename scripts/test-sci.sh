#!/usr/bin/env bash
# =============================================================================
# v2.0 科学环境测试
# 用法: ./scripts/test-sci.sh
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

IMAGE_PREFIX="${IMAGE_PREFIX:-ljm820/sagemath-fnos}"
echo ">>> 测试镜像: $IMAGE_PREFIX:debian12-sage9.5 (科学环境)"
IMAGE="$IMAGE_PREFIX:debian12-sage9.5" bash "$ROOT/tests/smoke-sci.sh"
echo ">>> 科学环境测试全部完成"
