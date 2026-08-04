#!/bin/sh
# =============================================================================
# SageMath + JupyterLab 容器入口脚本
#
# 行为:
#   1. 若传入命令为 sage / python / python3 / jupyter / bash / sh 等,
#      则直接执行该命令 (便于调试与测试)。
#   2. 否则启动 JupyterLab:
#      - 创建并确保工作目录可写
#      - 注册 SageMath Jupyter 内核 (幂等)
#      - 以非 root 用户启动 jupyter lab
#
# 可配置环境变量:
#   JUPYTER_PORT   JupyterLab 监听端口, 默认 8888
#   JUPYTER_TOKEN  JupyterLab 访问令牌, 默认 sagemath
#   WORK_DIR       工作目录, 默认 /home/sage/work
# =============================================================================
set -e

: "${JUPYTER_PORT:=8888}"
: "${JUPYTER_TOKEN:=sagemath}"
: "${WORK_DIR:=/home/sage/work}"

# 直接执行调试命令
case "$1" in
    sage|python|python3|jupyter|pip|pip3|bash|sh|zsh|fish)
        exec "$@"
        ;;
esac

# 若以默认 CMD (jupyter-lab) 启动, 丢弃该参数, 避免被当作路径参数传给 jupyter lab
if [ "$1" = "jupyter-lab" ]; then
    shift
fi

# 确保工作目录存在且可写
mkdir -p "$WORK_DIR"
chown -R "$(id -u):$(id -g)" "$WORK_DIR" 2>/dev/null || true

# 注册 SageMath Jupyter 内核 (幂等, 失败不阻塞启动)
if command -v sage >/dev/null 2>&1; then
    sage --python -m sage.repl.ipython_kernel install --user >/dev/null 2>&1 || true
fi

exec jupyter lab \
    --ip=0.0.0.0 \
    --port="${JUPYTER_PORT}" \
    --no-browser \
    --ServerApp.allow_root=true \
    --ServerApp.root_dir="${WORK_DIR}" \
    --IdentityProvider.token="${JUPYTER_TOKEN}" \
    "$@"
