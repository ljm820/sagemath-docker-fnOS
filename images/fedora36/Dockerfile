# =============================================================================
# SageMath + JupyterLab -- Fedora 36 版本 (对应 RHEL 8.8 系列)
#
# 基础镜像 : fedora:36 (quay.io/fedora/fedora:36)
# SageMath  : 9.6 (Fedora 36 官方仓库 sagemath-standard 包)
# Python    : 3.10 (Fedora 36 系统 Python)
# 注意      : Fedora 36 已于 2023-05 停止维护(EOL), 官方软件源已下线,
#             因此 Dockerfile 内先将 dnf 源切换到 Fedora 归档镜像站
#             (archives.fedoraproject.org) 后再安装软件包。
#
# 构建示例:
#   docker build -t ljm820/sagemath-fnos:fedora36-sage9.6 images/fedora36
# =============================================================================
FROM fedora:36

LABEL org.opencontainers.image.title="sagemath-fnos" \
      org.opencontainers.image.description="SageMath + JupyterLab on Fedora 36 (RHEL 8.8 era) for fnOS" \
      org.opencontainers.image.source="https://github.com/ljm820/sagemath-docker-fnOS" \
      org.opencontainers.image.version="fedora36-sage9.6" \
      org.opencontainers.image.licenses="Apache-2.0"

ENV LANG=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    SAGE_USER=sage \
    SAGE_UID=1000 \
    JUPYTER_PORT=8888 \
    JUPYTER_TOKEN=sagemath \
    WORK_DIR=/home/sage/work

# -----------------------------------------------------------------------------
# Fedora 36 EOL 源切换:
#   1) 注释掉 metalink, 启用被注释的 baseurl
#   2) 将 download.fedoraproject.org 替换为 archives.fedoraproject.org
# -----------------------------------------------------------------------------
RUN sed -i 's/^metalink=/#metalink=/; s/^#baseurl=/baseurl=/' /etc/yum.repos.d/*.repo \
    && sed -i 's|https://download.fedoraproject.org/pub/fedora/linux|https://archives.fedoraproject.org/pub/archive/fedora/linux|g' /etc/yum.repos.d/*.repo

RUN dnf -y install \
        tini \
        curl \
        ca-certificates \
        sagemath-standard \
        python3-pip \
    && dnf clean all

# JupyterLab 4 + 交互组件
# Fedora 36 未启用 PEP 668, pip 可直接写入系统 Python
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt \
    && rm -f /tmp/requirements.txt

# 创建非 root 运行用户
RUN useradd --uid "${SAGE_UID}" --create-home --shell /bin/bash "${SAGE_USER}" \
    && mkdir -p "${WORK_DIR}" \
    && chown -R "${SAGE_USER}:${SAGE_USER}" /home/sage

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR "${WORK_DIR}"
USER "${SAGE_USER}"

# 注册 Jupyter 内核
#  - python3 内核 : ipykernel 自带 (先 RUN 以 sage 用户创建目录, 再 COPY)
#  - sagemath 内核: 静态 kernelspec (argv 指向 /usr/bin/sage)
RUN python3 -m ipykernel install --user
COPY kernelspec/sagemath /home/sage/.local/share/jupyter/kernels/sagemath

EXPOSE 8888

ENTRYPOINT ["tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["jupyter-lab"]
