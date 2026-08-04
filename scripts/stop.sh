#!/usr/bin/env bash
# =============================================================================
# 停止并删除 SageMath 容器
# 用法: ./scripts/stop.sh [debian12|fedora36|alpine|all]
# =============================================================================
set -euo pipefail

STOP_ALL="${1:-all}"
declare -A NAMES=( [debian12]="sagemath-debian12" [fedora36]="sagemath-fedora36" [alpine]="sagemath-alpine" )

for name in debian12 fedora36 alpine; do
  if [ "$STOP_ALL" = "all" ] || [ "$STOP_ALL" = "$name" ]; then
    c="${NAMES[$name]}"
    if docker ps -a --format '{{.Names}}' | grep -qx "$c"; then
      echo ">>> 停止并删除 $c"
      docker rm -f "$c" >/dev/null
    else
      echo ">>> $c 不存在, 跳过"
    fi
  fi
done
echo ">>> 完成"
