#!/usr/bin/env bash
# =============================================================================
# 运行 SageMath + JupyterLab 容器 (docker run 方式)
# 用法: ./scripts/run.sh [debian12|fedora36|alpine]
# 环境: PORT 映射端口 / JUPYTER_TOKEN / WORK_DATA
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

IMAGE_PREFIX="${IMAGE_PREFIX:-ljm820/sagemath-fnos}"
NAME="${1:-debian12}"
TOKEN="${JUPYTER_TOKEN:-sagemath}"
WORK_DATA="${WORK_DATA:-$ROOT/work}"

declare -A TAG=(
  [debian12]="debian12-sage9.5"
  [fedora36]="fedora36-sage9.6"
  [alpine]="alpine-sage10x-experimental"
)
declare -A DEF_PORT=(
  [debian12]="8888"
  [fedora36]="8889"
  [alpine]="8890"
)

PORT="${PORT:-${DEF_PORT[$NAME]}}"
CONTAINER="sagemath-$NAME"

mkdir -p "$WORK_DATA"

echo ">>> 启动 $CONTAINER ($IMAGE_PREFIX:${TAG[$NAME]}) -> 0.0.0.0:$PORT"
docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  -p "$PORT:8888" \
  -e JUPYTER_TOKEN="$TOKEN" \
  -v "$WORK_DATA:/home/sage/work" \
  "$IMAGE_PREFIX:${TAG[$NAME]}"

echo ">>> 完成。浏览器访问 http://<主机IP>:$PORT  (令牌: $TOKEN)"
echo ">>> 查看日志: docker logs -f $CONTAINER"
