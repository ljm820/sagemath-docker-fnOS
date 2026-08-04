#!/usr/bin/env bash
# =============================================================================
# 飞牛OS (fnOS, 基于 Debian 12) 一键部署脚本
# 需在飞牛OS 上执行, 前置条件:
#   * 已安装 Docker 与 docker compose 插件 (fnOS 应用中心可安装 Docker)
#   * 已开启 SSH 或使用 fnOS 终端 (文件/存储池需可挂载到 /vol1/1000/docker)
#
# 用法: bash deploy.sh
# 环境: REPO_URL 仓库地址 (默认 https://github.com/ljm820/sagemath-docker-fnOS.git)
#       DIR      部署目录 (默认 /vol1/1000/docker/sagemath)
# =============================================================================
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/ljm820/sagemath-docker-fnOS.git}"
DIR="${DIR:-/vol1/1000/docker/sagemath}"
FLAVOR="${FLAVOR:-debian12}"

echo ">>> 1. 获取项目代码"
if [ ! -d "$DIR/.git" ]; then
  mkdir -p "$DIR"
  git clone "$REPO_URL" "$DIR"
else
  git -C "$DIR" pull
fi
cd "$DIR"

echo ">>> 2. 生成 .env (若不存在)"
cp -n .env.example .env || true

echo ">>> 3. 校验 Docker 环境"
docker --version
docker compose version

echo ">>> 4. 构建镜像: $FLAVOR (首次构建需下载依赖, Debian 版约 10~20 分钟)"
./scripts/build.sh "$FLAVOR"

echo ">>> 5. 启动容器"
docker compose up -d "$FLAVOR"
docker compose ps

echo ">>> 完成。"
echo "    浏览器访问:  http://<飞牛OS的IP>:$([ "$FLAVOR" = debian12 ] && echo 8888 || ([ "$FLAVOR" = fedora36 ] && echo 8889 || echo 8890))"
echo "    Jupyter 令牌: 见 $DIR/.env 中的 JUPYTER_TOKEN"
echo "    Notebook 数据: $DIR/work"
