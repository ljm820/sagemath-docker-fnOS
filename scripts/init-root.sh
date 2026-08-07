#!/bin/sh
# init-root.sh —— 容器启动时一次性初始化(root 密码 / 普通用户 sudo)
# 用法:在 docker-compose.yml 中以 entrypoint 方式挂载,脚本末尾 exec "$@" 续跑镜像原命令
set -e

# 1) 设置 root 密码(优先从环境变量 ROOT_PASSWORD 读取,避免明文写死在 compose)
if [ -n "$ROOT_PASSWORD" ]; then
  echo "root:${ROOT_PASSWORD}" | chpasswd
fi

# 2) 给指定普通用户授予 sudo 免密(可选,设置 SUDO_USER 即启用)
if [ -n "$SUDO_USER" ]; then
  command -v sudo >/dev/null 2>&1 || (apt-get update >/dev/null 2>&1 && apt-get install -y sudo >/dev/null 2>&1)
  usermod -aG sudo "$SUDO_USER" 2>/dev/null || true
  echo "${SUDO_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${SUDO_USER}"
  chmod 440 "/etc/sudoers.d/${SUDO_USER}"
fi

# 3) 继续执行镜像原本的启动命令(由 compose 的 command: 传入)
exec "$@"
