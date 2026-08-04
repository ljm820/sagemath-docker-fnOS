#!/usr/bin/env bash
# =============================================================================
# 构建 SageMath 镜像
# 用法: ./scripts/build.sh [all|debian12|fedora36|alpine]
# 环境: IMAGE_PREFIX 镜像名前缀 (默认 ljm820/sagemath-fnos)
#       PLATFORMS    构建平台 (默认 linux/amd64)
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

IMAGE_PREFIX="${IMAGE_PREFIX:-ljm820/sagemath-fnos}"
PLATFORMS="${PLATFORMS:-linux/amd64}"

declare -A IMAGES=(
  [debian12]="debian12-sage9.5"
  [fedora36]="fedora36-sage9.6"
  [alpine]="alpine-sage10x-experimental"
)

build_one() {
  local name="$1"
  local tag="${IMAGES[$name]}"
  local target="$IMAGE_PREFIX:$tag"
  echo ">>> 构建 $target  (images/$name, 平台=$PLATFORMS)"
  docker build --platform "$PLATFORMS" -t "$target" "images/$name"
  echo ">>> 完成: $target"
}

case "${1:-all}" in
  all)
    for n in debian12 fedora36 alpine; do build_one "$n"; done
    ;;
  debian12|fedora36|alpine)
    build_one "$1"
    ;;
  *)
    echo "用法: $0 [all|debian12|fedora36|alpine]"
    exit 1
    ;;
esac

echo ">>> 全部构建完成"
