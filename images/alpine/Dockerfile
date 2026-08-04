# =============================================================================
# SageMath + JupyterLab -- Alpine 3.20 版本 (实验性)
#
# 基础镜像 : alpine:3.20
# SageMath  : sagemath-standard (PyPI 最新稳定版, 例如 10.x)
# Python    : 3.12 (Alpine 3.20 系统 Python)
#
# 重要警告 (务必阅读):
#   * SageMath 上游官方仅支持 glibc, 不支持 musl libc (Alpine 使用 musl)。
#   * PyPI 上的 sagemath-standard 目前只有源码包(sdist), 没有预编译 wheel,
#     因此 pip 安装 = 从源码编译整个 SageMath, 需要 2~4 小时以上、8GB+ 内存。
#   * 在 musl 上源码编译可能失败 (linbox/giac 等依赖对 musl 支持不足)。
#   * 结论: 本镜像仅作为"最小体积/实验性"版本提供。生产环境请使用
#           Debian 12 版本 (ljm820/sagemath-fnos:debian12-sage9.5)。
#
# 构建示例:
#   docker build -t ljm820/sagemath-fnos:alpine-sage10x-experimental images/alpine
# =============================================================================
FROM alpine:3.20

LABEL org.opencontainers.image.title="sagemath-fnos" \
      org.opencontainers.image.description="SageMath + JupyterLab on Alpine (experimental, musl) for fnOS" \
      org.opencontainers.image.source="https://github.com/ljm820/sagemath-docker-fnOS" \
      org.opencontainers.image.version="alpine-sage10x-experimental" \
      org.opencontainers.image.licenses="Apache-2.0"

ENV LANG=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    SAGE_USER=sage \
    SAGE_UID=1000 \
    JUPYTER_PORT=8888 \
    JUPYTER_TOKEN=sagemath \
    WORK_DIR=/home/sage/work

# SageMath 源码编译所需的基础工具链与数学库
RUN apk add --no-cache \
        python3 \
        py3-pip \
        py3-setuptools \
        py3-wheel \
        gcc \
        g++ \
        gfortran \
        make \
        patch \
        musl-dev \
        python3-dev \
        linux-headers \
        gmp-dev \
        mpfr-dev \
        mpc1-dev \
        flint-dev \
        tini \
        curl \
        bash \
    && pip3 install --no-cache-dir --upgrade pip

# 从源码构建 sagemath-standard + JupyterLab (见上方警告)
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt \
    && rm -f /tmp/requirements.txt

# 创建非 root 运行用户
RUN adduser --disabled-password --uid "${SAGE_UID}" --home /home/sage "${SAGE_USER}" \
    && mkdir -p "${WORK_DIR}" \
    && chown -R "${SAGE_USER}:${SAGE_USER}" /home/sage

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR "${WORK_DIR}"
USER "${SAGE_USER}"

# 注册 Jupyter 内核
#  - python3 内核 : ipykernel 自带 (先 RUN 以 sage 用户创建目录, 再 COPY)
#  - sagemath 内核: 静态 kernelspec (argv 指向 /usr/local/bin/sage)
RUN python3 -m ipykernel install --user
COPY kernelspec/sagemath /home/sage/.local/share/jupyter/kernels/sagemath

EXPOSE 8888

ENTRYPOINT ["tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["jupyter-lab"]
