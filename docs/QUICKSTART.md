# 快速开始

本指南适用于任何 Docker 主机（含飞牛OS）。飞牛OS 专属步骤见
`fnos/fnos-notes.md`。

## 1. 前置条件

- Docker Engine 20.10+（飞牛OS 应用中心安装）
- Docker Compose 插件（fnOS 自带；或 `docker compose` 子命令）
- git、curl

## 2. 克隆与配置

```bash
git clone https://github.com/ljm820/sagemath-docker-fnOS.git
cd sagemath-docker-fnOS
cp .env.example .env
```

编辑 `.env`：

```ini
IMAGE_PREFIX=ljm820/sagemath-fnos   # 自建镜像名前缀
JUPYTER_TOKEN=换成你的强密码         # JupyterLab 登录令牌
DEBIAN_PORT=8888                    # Debian 版对外端口
FEDORA_PORT=8889
ALPINE_PORT=8890
WORK_DATA=./work                    # 数据目录
```

## 3. 构建镜像

```bash
./scripts/build.sh debian12          # 仅 Debian 12 版本（推荐）
./scripts/build.sh all               # 三个版本全部构建
```

- 平台默认 `linux/amd64`；arm64 设备：`PLATFORMS=linux/arm64 ./scripts/build.sh debian12`
- 构建日志出现 `=> exporting to image` 即成功。

## 4. 启动

```bash
./scripts/run.sh debian12
# 或
docker compose up -d debian12
```

确认运行：

```bash
docker ps --filter name=sagemath-debian12
docker logs sagemath-debian12        # 看到 Jupyter Server ... http://127.0.0.1:8888/lab
```

浏览器访问 `http://<主机IP>:8888/lab`，令牌填 `.env` 中 `JUPYTER_TOKEN`。

## 5. 首个 Notebook

1. Launcher 中选择 **SageMath** 内核新建 Notebook；
2. 输入 `print(factor(2^127 - 1))`，`Shift+Enter` 执行；
3. 数据保存在挂载目录 `./work`（容器内 `/home/sage/work`），容器重建不丢失。

## 6. 停止 / 删除

```bash
./scripts/stop.sh debian12           # 或 docker compose stop/rm
```

## 常见问题

| 现象 | 处理 |
|------|------|
| 8888 端口被占用 | 修改 `.env` 的 `DEBIAN_PORT` 后 `docker compose up -d` |
| 挂载目录无权限 | `chown -R 1000:1000 <WORK_DATA>` |
| 浏览器访问被拒 | 检查防火墙是否放行端口 |
| 令牌失效/忘记 | `docker exec sagemath-debian12 jupyter server list` 查看当前 token |
