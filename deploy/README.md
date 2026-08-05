# SageMath + JupyterLab 部署说明 (飞牛OS / Docker)

## 下载修复版镜像

最新修复版镜像（标准 docker-archive 格式，manifest/RepoTags 完整，`docker load` 后
tag 即为 `sagemath9.5_deb12_julab:latest`，无需再手动 tag）：

```bash
wget https://github.com/ljm820/sagemath-docker-fnOS/releases/download/v1.0.0/sagemath9.5_deb12_julab_latest.tar.gz
sha256sum sagemath9.5_deb12_julab_latest.tar.gz
# 期望: 3b47452f7b3f5c7570254551c69081913d57dbe975d87814d84c4e5e135edf8b
docker load -i sagemath9.5_deb12_julab_latest.tar.gz
```

## 镜像内关键路径

| 组件 | 位置 |
|------|------|
| jupyter 主程序 | `/usr/local/bin/jupyter` |
| jupyter-lab | `/usr/local/bin/jupyter-lab` |
| sage 主程序 | `/usr/bin/sage` |
| 内核规范 | `/home/sage/.local/share/jupyter/kernels/{python3,sagemath}` |
| 默认工作目录 | `/home/sage/work` |

## "no command specified" 根因与修复

原 `sagemath9.5_fnos_debain12.tar.gz` 归档损坏：gzip 校验失败、`manifest.json`
的 tar header 无效，导致 `docker load` 后镜像未恢复默认 CMD/Entrypoint（表现为
无标签悬空镜像）。镜像内部内容本身完好，只是归档文件格式有缺陷。

修复版 `sagemath9.5_deb12_julab_latest.tar.gz`：
- gzip 完整性通过校验（`gzip -t`）
- manifest 含正确 RepoTags（`sagemath9.5_deb12_julab:latest`）与 CMD
- 已用 Go archive/tar（Docker daemon 同款解析器）与容器引擎实测 load + 默认
  CMD 启动通过（HTTP 200，`sage --version` 正常）

部署配置中保留显式 `command` 作为双保险（旧镜像也可用）。

## 部署步骤

### 1. 加载修复版镜像

```bash
docker load -i sagemath9.5_deb12_julab_latest.tar.gz
docker images   # 应看到 sagemath9.5_deb12_julab:latest
```

### 2a. 使用 docker compose 启动

```bash
cp deploy/docker-compose.yml /vol1/1000/_0.DataStation/_0.dockerStation/sagemath_lvscript_docker/
cd /vol1/1000/_0.DataStation/_0.dockerStation/sagemath_lvscript_docker/
# 编辑 docker-compose.yml 把两处 change_me_to_your_token 换成你的令牌
docker compose up -d
```

### 2b. 或使用 docker run 启动

```bash
JUPYTER_TOKEN=你的令牌 bash deploy/docker-run.sh
```

### 3. 访问

浏览器打开 `http://<NAS-IP>:36888`，令牌见上。

工作区数据持久化在
`/vol1/1000/_0.DataStation/_0.dockerStation/sagemath_lvscript_docker/workspace`。

## 验证

```bash
docker exec sagemath-debian12 sage --version
docker exec sagemath-debian12 jupyter kernelspec list   # python3 + sagemath
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:36888/lab?token=你的令牌"  # 200
```
