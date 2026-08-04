# =============================================================================
# SageMath + JupyterLab -- Debian 12 (bookworm) 版本
#
# 基础镜像 : debian:12-slim
# SageMath  : 9.5 (Debian bookworm 官方软件源, python3-sage 9.5-6)
# Python    : 3.11 (Debian 12 系统 Python)
# 适用场景  : 飞牛OS(fnOS, 基于 Debian 12) 上最推荐、兼容性最好的版本
#
# 构建示例:
#   docker build -t ljm820/sagemath-fnos:debian12-sage9.5 images/debian12
# =============================================================================
FROM debian:12-slim

LABEL org.opencontainers.image.title="sagemath-fnos" \
      org.opencontainers.image.description="SageMath + JupyterLab on Debian 12 for fnOS" \
      org.opencontainers.image.source="https://github.com/ljm820/sagemath-docker-fnOS" \
      org.opencontainers.image.version="debian12-sage9.5" \
      org.opencontainers.image.licenses="Apache-2.0"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    SAGE_USER=sage \
    SAGE_UID=1000 \
    JUPYTER_PORT=8888 \
    JUPYTER_TOKEN=sagemath \
    WORK_DIR=/home/sage/work

# tini 作为 PID 1：正确转发信号并回收孤儿进程
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tini \
        curl \
        ca-certificates \
        sagemath \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

# JupyterLab 4 + 交互组件
# 注意: Debian 12 启用了 PEP 668 (externally-managed-environment),
#       因此对系统 Python 安装 Python 包必须加 --break-system-packages
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt \
    && rm -f /tmp/requirements.txt

# 创建非 root 运行用户, 便于与 NAS 上的 UID 对齐
RUN useradd --uid "${SAGE_UID}" --create-home --shell /bin/bash "${SAGE_USER}" \
    && mkdir -p "${WORK_DIR}" \
    && chown -R "${SAGE_USER}:${SAGE_USER}" /home/sage

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR "${WORK_DIR}"
USER "${SAGE_USER}"

# 注册 Jupyter 内核
#  - python3 内核 : ipykernel 自带 (先 RUN 以 sage 用户创建目录, 再 COPY)
#  - sagemath 内核: Debian 版 sage.repl.ipython_kernel 无 install 子命令,
#                   因此使用静态 kernelspec (argv 指向 /usr/bin/sage)
RUN python3 -m ipykernel install --user
COPY kernelspec/sagemath /home/sage/.local/share/jupyter/kernels/sagemath

EXPOSE 8888

ENTRYPOINT ["tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["jupyter-lab"]
