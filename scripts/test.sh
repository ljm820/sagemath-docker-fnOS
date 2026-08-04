#!/usr/bin/env bash
# =============================================================================
# 构建并运行镜像测试
# 用法: ./scripts/test.sh [debian12|fedora36|alpine|all]
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

declare -A TAG=(
  [debian12]="debian12-sage9.5"
  [fedora36]="fedora36-sage9.6"
  [alpine]="alpine-sage10x-experimental"
)

run_test() {
  local name="$1"
  echo "=========================================="
  echo " 测试镜像: $name (${TAG[$name]})"
  echo "=========================================="
  IMAGE="$IMAGE_PREFIX:${TAG[$name]}" IMAGE_PREFIX="${IMAGE_PREFIX:-ljm820/sagemath-fnos}" \
    bash "$ROOT/tests/smoke.sh"
}

IMAGE_PREFIX="${IMAGE_PREFIX:-ljm820/sagemath-fnos}"
case "${1:-all}" in
  all) for n in debian12 fedora36 alpine; do run_test "$n"; done ;;
  debian12|fedora36|alpine) run_test "$1" ;;
  *) echo "用法: $0 [all|debian12|fedora36|alpine]"; exit 1 ;;
esac
echo ">>> 全部测试完成"
