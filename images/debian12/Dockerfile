# =============================================================================
# SageMath + JupyterLab -- Debian 12 (bookworm) 版本  (v2.0)
#
# 基础镜像 : debian:12-slim
# SageMath  : 9.5 (Debian bookworm 官方软件源, python3-sage 9.5-6)
# Python    : 3.11 (Debian 12 系统 Python)
# 适用场景  : 飞牛OS(fnOS, 基于 Debian 12) 上最推荐、兼容性最好的版本
# v2.0 新增 : 科学仪器数据分析环境 (XRD/EDS/XAS), 见 /opt/sci-env
#
# 构建示例:
#   docker build -t ljm820/sagemath-fnos:debian12-sage9.5 images/debian12
# =============================================================================
FROM debian:12-slim

LABEL org.opencontainers.image.title="sagemath-fnos" \
      org.opencontainers.image.description="SageMath + JupyterLab + 科学仪器数据分析(XRD/EDS/XAS) on Debian 12 for fnOS" \
      org.opencontainers.image.source="https://github.com/ljm820/sagemath-docker-fnOS" \
      org.opencontainers.image.version="v2.0" \
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

# =============================================================================
# v2.0: 科学仪器数据分析环境 (XRD / EDS / XAS)
#
# 采用独立 venv (/opt/sci-env) 隔离, 避免升级 numpy/scipy 等破坏 SageMath
# 9.5 依赖的系统包。科学环境作为 jupyter 的默认 python3 内核使用。
# 参考: github.com/ljm820/pyXRD_EDS_XAS_Env (conda 版) 移植到 Docker + Python 3.11
# =============================================================================
USER root

# python3-venv: Debian 12 上 python3 -m venv 需要 ensurepip 支持
# libegl1/libgl1/libopengl0 等: OVITO/PySide6 无头运行所需 Qt 图形库
# (ovito import 依赖 libEGL/libOpenGL/libxkbcommon/xcb, 缺失会 ImportError)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3-venv \
        libegl1 libgl1 libopengl0 libglx0 libxkbcommon0 \
        libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 \
        libxcb-render-util0 libxcb-shape0 libxcb-xinerama0 libxcb-xkb1 \
        libxcb-cursor0 libdbus-1-3 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 创建独立 venv (Python 3.11, 与 Debian 12 系统 Python 一致)
RUN python3 -m venv /opt/sci-env

# 核心科学包 + 仪器数据读取 + 材料计算 (见 requirements-sci.txt 与版本说明)
COPY requirements-sci.txt /tmp/requirements-sci.txt
RUN /opt/sci-env/bin/pip install --no-cache-dir \
      -r /tmp/requirements-sci.txt \
    && rm -f /tmp/requirements-sci.txt

# torch CPU 版 (独立 index, 适配 Python 3.11; CPU 推理足够科学计算场景)
RUN /opt/sci-env/bin/pip install --no-cache-dir \
      --index-url https://download.pytorch.org/whl/cpu \
      torch

# PyXplore: AI 驱动 XRD 全谱精修 (依赖与 numpy>=2 冲突, 采用无依赖安装,
# 参考 pyXRD_EDS_XAS_Env v1 同款处理)
RUN /opt/sci-env/bin/pip install --no-cache-dir --no-deps PyXplore

# OVITO Python 模块 (免费版, 原子/粒子模拟可视化; OVITO Pro 桌面版需商业授权,
# 见 docs/SCIENCE.md 说明)
RUN /opt/sci-env/bin/pip install --no-cache-dir ovito

USER sage

# 注册 Jupyter 内核
#  - python3 内核 : 指向科学环境 /opt/sci-env (默认 Python 内核, 覆盖系统 ipykernel)
#  - sagemath 内核: Debian 版 sage.repl.ipython_kernel 无 install 子命令,
#                   因此使用静态 kernelspec (argv 指向 /usr/bin/sage)
RUN /opt/sci-env/bin/python -m ipykernel install --user --name python3 \
      --display-name "Python 3.11 (Science)"
COPY kernelspec/sagemath /home/sage/.local/share/jupyter/kernels/sagemath

USER root
RUN chown -R sage:sage /home/sage/.local

EXPOSE 8888

ENTRYPOINT ["tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["jupyter-lab"]
