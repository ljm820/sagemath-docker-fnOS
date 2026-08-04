#!/usr/bin/env bash
# =============================================================================
# 将构建好的镜像推送到 Docker Hub / GHCR
# 用法: ./scripts/push-images.sh
# 环境: REGISTRY      (默认 docker.io, 可设为 ghcr.io)
#       IMAGE_PREFIX  (默认 ljm820/sagemath-fnos)
# 注意: 推送前请先 docker login
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REGISTRY="${REGISTRY:-docker.io}"
IMAGE_PREFIX="${IMAGE_PREFIX:-ljm820/sagemath-fnos}"
if [ -n "$REGISTRY" ] && [ "$REGISTRY" != "docker.io" ]; then
  IMAGE_PREFIX="$REGISTRY/$IMAGE_PREFIX"
fi

echo ">>> 登录 $REGISTRY (需要交互输入账号/令牌)"
docker login "$REGISTRY"

for t in debian12-sage9.5 fedora36-sage9.6 alpine-sage10x-experimental; do
  echo ">>> push $IMAGE_PREFIX:$t"
  docker push "$IMAGE_PREFIX:$t"
done
echo ">>> 推送完成"
