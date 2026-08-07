# =============================================================================
# SageMath + JupyterLab -- Debian 12 (bookworm) 版本  (v3.0)
#
# 基础镜像 : debian:12-slim
# SageMath  : 9.5 (Debian bookworm 官方软件源, python3-sage 9.5-6)
# Python    : 3.11 (Debian 12 系统 Python)
# 适用场景  : 飞牛OS(fnOS, 基于 Debian 12) 上最推荐、兼容性最好的版本
#
# v3.0 相对 v2.0 的变更:
#   1. [修复] JupyterLab Launcher(Notebook/Console 栏) 缺失 sagemath 图标:
#      - 双内核(kernelspec)改为【全局注册】到 /usr/local/share/jupyter/kernels,
#        不再只写用户家目录, 避免被数据卷挂载 /home/sage 或 --user 安装覆盖,
#        导致 Launcher 中看不到 sagemath。
#      - 为 sagemath 内核补齐官方 logo 资源 (logo-32x32.png / logo-64x64.png,
#        取自 sagemath/sage 官方 ext_data/notebook-ipython), Launcher 卡片与
#        Select Kernel 下拉均显示 SageMath 专属图标。
#      - entrypoint 去掉脆弱的 `sage --python -m sage.repl.ipython_kernel install`
#        逻辑, 内核在镜像构建期一次性固化, 启动更稳。
#   2. [集成] /opt/sci-env 对齐 pyXRD_EDS_XAS_Env v1 (pymatgen 2025.10.7 +
#      crystal-toolkit + pymatviz + PyXplore(--no-deps) + hyperspy[all] +
#      rosettasciio + xraylarch) 并保留 torch(CPU)。
#   3. [瘦身] 移除冗余大包(PySide6/open3d 等, deltalake 保留), 清理 __pycache__/
#      .pyc/pip cache/apt lists/tests/doc/man/静态库, 镜像体积较 v2.0 再降。
#
# 构建示例:
#   docker build -t ljm820/sagemath-fnos:debian12-sage9.5 images/debian12
# =============================================================================
FROM debian:12-slim

LABEL org.opencontainers.image.title="sagemath-fnos" \
      org.opencontainers.image.description="SageMath + JupyterLab + 科学仪器数据分析(XRD/EDS/XAS) on Debian 12 for fnOS (v3.0)" \
      org.opencontainers.image.source="https://github.com/ljm820/sagemath-docker-fnOS" \
      org.opencontainers.image.version="v3.0" \
      org.opencontainers.image.licenses="Apache-2.0"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    SAGE_USER=sage \
    SAGE_UID=1000 \
    JUPYTER_PORT=8888 \
    JUPYTER_TOKEN=sagemath \
    WORK_DIR=/home/sage/work \
    SCI_ENV=/opt/sci-env

# tini 作为 PID 1：正确转发信号并回收孤儿进程
# (sagemath 独立 RUN, 便于构建缓存复用; 见 SESSION_SUMMARY 第 5 节)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        sagemath \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tini \
        curl \
        ca-certificates \
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
# v2.0+ 延续: 科学仪器数据分析环境 (XRD / EDS / XAS)
#
# 独立 venv (/opt/sci-env) 隔离, 避免升级 numpy/scipy 等破坏 SageMath 9.5
# 依赖的系统包。参考: github.com/ljm820/pyXRD_EDS_XAS_Env (v1, conda 版)
# 移植到 Docker + Python 3.11。
# =============================================================================
USER root

# python3-venv: Debian 12 上 python3 -m venv 需要 ensurepip 支持
# libegl1/libgl1 等: ovito 无头运行所需 Qt 图形库
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3-venv \
        libegl1 libgl1 libopengl0 libglx0 libxkbcommon0 \
        libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 \
        libxcb-render-util0 libxcb-shape0 libxcb-xinerama0 libxcb-xkb1 \
        libxcb-cursor0 libdbus-1-3 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 创建独立 venv (Python 3.11, 与 Debian 12 系统 Python 一致)
RUN python3 -m venv "${SCI_ENV}"

# 核心科学包 + 仪器数据读取 + 材料计算 (见 requirements-sci.txt)
COPY requirements-sci.txt /tmp/requirements-sci.txt
RUN "${SCI_ENV}/bin/pip" install --no-cache-dir \
      -r /tmp/requirements-sci.txt \
    && rm -f /tmp/requirements-sci.txt

# torch CPU 版 (独立 index, 适配 Python 3.11; CPU 推理足够科学计算场景)
RUN "${SCI_ENV}/bin/pip" install --no-cache-dir \
      --index-url https://download.pytorch.org/whl/cpu \
      torch

# PyXplore: AI 驱动 XRD 全谱精修 (依赖与 numpy>=2 冲突, 采用无依赖安装,
# 参考 pyXRD_EDS_XAS_Env v1 同款处理)
RUN "${SCI_ENV}/bin/pip" install --no-cache-dir --no-deps PyXplore

# OVITO Python 模块 (免费版; OVITO Pro 桌面版需商业授权, 见 docs/SCIENCE.md)
RUN "${SCI_ENV}/bin/pip" install --no-cache-dir ovito

# =============================================================================
# v3.0 瘦身: 移除冗余大包, 保留 pyXRD_EDS_XAS_Env 核心功能
#   - PySide6 (~647M): ovito 的 Qt 绑定; 参考环境不含 ovito, 一并移除
#   - deltalake: crystal_toolkit 模块级依赖, 保留并固定 1.5.1 (满足 mp-api 约束)
#   - open3d: 未在参考环境 (若被传递引入)
#   - 移除后重跑冒烟测试确保科学包导入不受影响 (见 tests/smoke-sci.sh)
# =============================================================================
RUN "${SCI_ENV}/bin/pip" uninstall -y -q PySide6 PySide6-Essentials PySide6-Addons shiboken6 2>/dev/null || true; \
    "${SCI_ENV}/bin/pip" uninstall -y -q ovito 2>/dev/null || true; \
    "${SCI_ENV}/bin/pip" uninstall -y -q open3d 2>/dev/null || true

# =============================================================================
# v3.0 修复: Jupyter 内核【全局】注册 + Launcher 图标
#   - sagemath: 静态 kernelspec(含官方 logo 图标) -> /usr/local/share/jupyter/kernels
#   - python3 : 默认科学内核 -> 指向 /opt/sci-env (显示 Python 3.11 (Science))
#   - sci-env : 具名科学内核(别名, 便于 Launcher 识别选择)
#   - 全容器所有用户可见, 不依赖 /home/sage/.local, 数据卷挂载也不影响
# =============================================================================
RUN "${SCI_ENV}/bin/python" -m ipykernel install --prefix=/usr/local \
         --name python3 \
         --display-name "Python 3.11 (Science)" \
    && "${SCI_ENV}/bin/python" -m ipykernel install --prefix=/usr/local \
         --name sci-env \
         --display-name "Python 3.11 (sci-env, 材料计算)"

# sagemath 内核 (全局, 含官方图标资源)
COPY kernelspec/sagemath /usr/local/share/jupyter/kernels/sagemath

# 生成科学内核 Launcher 图标 (logo-32x32.png / logo-64x64.png), 与
# 《JupyterLab多环境内核注册与使用方案.md》第 11 节配色一致
COPY scripts/gen-kernel-icons.py /tmp/gen-kernel-icons.py
RUN "${SCI_ENV}/bin/python" /tmp/gen-kernel-icons.py \
        --kernel /usr/local/share/jupyter/kernels/python3 \
        --kernel /usr/local/share/jupyter/kernels/sci-env \
    && rm -f /tmp/gen-kernel-icons.py

# 权限对齐: /home/sage 归 sage 用户; /usr/local 内核文件全局可读
RUN chown -R "${SAGE_USER}:${SAGE_USER}" /home/sage \
    && chmod -R a+rX /usr/local/share/jupyter/kernels

# =============================================================================
# v3.0 缓存/冗余清理 (最小化镜像)
# =============================================================================
# 下载缓存与构建残留
RUN rm -rf /root/.cache /tmp/pip* "${SCI_ENV}/.cache" 2>/dev/null || true
# site-packages 内的 tests 目录 (不影响运行; 有冒烟测试兜底)
RUN find "${SCI_ENV}" /usr/lib/python3 /usr/local/lib/python3* -xdev \
        -type d \( -name 'tests' -o -name 'test' \) \
        -path '*/site-packages/*' -prune -exec rm -rf {} + 2>/dev/null || true
# __pycache__ / .pyc
RUN find "${SCI_ENV}" /usr/lib/python3 /usr/local/lib/python3* -xdev \
        -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true \
    && find "${SCI_ENV}" -xdev -type f -name '*.pyc' -delete 2>/dev/null || true
# 静态库 / libtool 文件
RUN find / -xdev -type f \( -name '*.a' -o -name '*.la' \) -delete 2>/dev/null || true
# apt 文档/man/info
RUN rm -rf /usr/share/doc /usr/share/man /usr/share/info /usr/share/lintian \
        /var/cache/apt /var/lib/apt/lists 2>/dev/null || true

USER "${SAGE_USER}"

EXPOSE 8888

ENTRYPOINT ["tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["jupyter-lab"]
