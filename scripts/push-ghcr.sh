#!/usr/bin/env bash
# =============================================================================
# v3.0: 推送镜像到 ghcr.io (skopeo)
#
# 背景 (SESSION_SUMMARY 第 5/7 节): 沙箱无 Docker, podman 4.3.1 的 load/oci
# transport 受限; v2.0 曾用 curl 手写 Docker Registry v2 协议推送。
# v3.0 起优先使用 skopeo (Go 实现, 与 Docker 同源), 更稳健。
#
# 用法:
#   export PAT='<ghcr 推送用 PAT (write:packages + delete:packages)>'
#   bash scripts/push-ghcr.sh <docker-archive|oci-dir> [tag] [repo]
#   示例: bash scripts/push-ghcr.sh sagemath9.5_deb12_julab_v3.0.tar.gz v3.0
#
# 镜像引用: ghcr.io/ljm820/sagemath-docker-fnos:v3.0 (仓库名全小写)
# =============================================================================
set -euo pipefail

SRC="${1:?需要指定 docker-archive / oci 目录}"
TAG="${2:-v3.0}"
REPO="${3:-ljm820/sagemath-docker-fnos}"
GHCR="ghcr.io/${REPO}:${TAG}"

: "${PAT:?需要设置 PAT 环境变量 (write:packages + delete:packages)}"

echo ">>> 源: $SRC"
echo ">>> 目标: $GHCR"

echo ">>> skopeo login ghcr.io ..."
skopeo login ghcr.io -u ljm820 --password "$PAT" >/dev/null 2>&1
echo "    login OK"

if [ -d "$SRC" ]; then
    skopeo copy "oci:$SRC" "docker://${GHCR}" \
        --retry-times 5 --override-os linux --override-arch amd64
else
    skopeo copy "docker-archive:$SRC" "docker://${GHCR}" \
        --retry-times 5 --override-os linux --override-arch amd64
fi

echo ">>> 推送成功: ${GHCR}"
