#!/usr/bin/env bash
# =============================================================================
# SageMath + JupyterLab 一键启动 (docker run, 等价于 deploy/docker-compose.yml)
#
# 用法: bash deploy/docker-run.sh
#   首次使用先加载镜像 (下载见 deploy/README.md):
#     docker load -i sagemath9.5_deb12_julab_latest.tar.gz
# =============================================================================
set -euo pipefail

IMAGE="sagemath9.5_deb12_julab:latest"
NAME="test_sage"
PORT="36888"
TOKEN="${JUPYTER_TOKEN:-change_me_to_your_token}"
WORKSPACE="/vol1/1000/_0.DataStation/_0.dockerStation/sagemath_lvscript_docker/workspace"

echo ">>> 启动 SageMath JupyterLab ..."
echo "    镜像:   ${IMAGE}"
echo "    端口:   ${PORT} -> 8888"
echo "    工作区: ${WORKSPACE} -> /home/sage/work"

docker run -d --name "${NAME}" \
  -p "${PORT}:8888" \
  -e "JUPYTER_TOKEN=${TOKEN}" \
  -e "TZ=Asia/Shanghai" \
  -v "${WORKSPACE}:/home/sage/work" \
  --restart unless-stopped \
  "${IMAGE}" \
  jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root "--ServerApp.token=${TOKEN}"

echo ">>> 已启动, 访问 http://<NAS-IP>:${PORT}  令牌: ${TOKEN}"
