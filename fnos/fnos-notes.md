# 飞牛OS (fnOS) 部署手册

飞牛OS 是基于 Debian 12 的 NAS 操作系统，自带 Docker 应用，因此本项目的
Debian 12 版本镜像与飞牛OS 的系统库完全同源，兼容性最佳，作为默认推荐版本。

## 1. 前置条件

| 项目       | 要求                                                          |
|------------|---------------------------------------------------------------|
| 系统       | 飞牛OS (基于 Debian 12)                                        |
| 硬件       | x86_64 或 arm64，内存建议 >= 8GB，磁盘空闲 >= 15GB              |
| Docker     | 在「应用中心」安装 Docker（自带 docker compose 插件）            |
| SSH        | 建议开启 SSH，方便复制命令（也可直接用 fnOS 的网页终端）          |

## 2. 获取项目

在飞牛OS 终端执行（路径可放在存储池，如 `/vol1/1000/docker/sagemath`）：

```bash
git clone https://github.com/ljm820/sagemath-docker-fnOS.git /vol1/1000/docker/sagemath
cd /vol1/1000/docker/sagemath
cp .env.example .env
```

## 3. 构建镜像（推荐 Debian 12 版本）

```bash
./scripts/build.sh debian12
```

- 构建时默认使用 `linux/amd64` 平台；arm64 设备可：
  `PLATFORMS=linux/arm64 ./scripts/build.sh debian12`
- 首次构建需下载 SageMath 软件包（约 1.5GB），耗时 10~20 分钟。

## 4. 启动容器

方式一（docker compose，推荐）：

```bash
docker compose up -d debian12      # 默认版本
docker compose up -d fedora36      # Fedora 36 版本 (端口 8889)
docker compose up -d alpine        # Alpine 实验版本 (端口 8890)
```

方式二（docker run）：

```bash
./scripts/run.sh debian12
```

启动后浏览器访问：

```
http://<飞牛OS的IP>:8888
```

Jupyter 令牌在 `.env` 的 `JUPYTER_TOKEN`（默认 `sagemath`）。首次登录填写令牌即可，
可在页面右上角设置密码。

## 5. 数据持久化

容器工作目录映射到 `WORK_DATA`（默认 `./work`）。建议修改 `.env`：

```ini
WORK_DATA=/vol1/1000/docker/sagemath/work
```

容器内以 `uid=1000`（用户 `sage`）运行。若挂载目录属主不是 1000，可执行：

```bash
sudo chown -R 1000:1000 /vol1/1000/docker/sagemath/work
```

## 6. 开机自启

compose 已设置 `restart: unless-stopped`，Docker 服务随系统启动后会自动拉起容器，
一般无需额外配置。如需 systemd 管理，可安装 `fnos/sagemath.service`。

## 7. 防火墙/端口

飞牛OS 若开启防火墙，需放行 8888（及 8889/8890）端口，或使用「应用」的端口转发。

## 8. 日常操作

| 操作       | 命令                                              |
|------------|---------------------------------------------------|
| 查看日志   | `docker logs -f sagemath-debian12`                |
| 停止       | `docker compose stop debian12`                    |
| 进入容器   | `docker exec -it sagemath-debian12 sage`          |
| 重启       | `docker compose restart debian12`                 |
| 更新镜像   | `git pull && ./scripts/build.sh debian12 && docker compose up -d debian12` |
