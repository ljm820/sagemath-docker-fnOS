# 迁移与部署指南

本文说明三种场景下的迁移/部署路径：
1. 从其他 SageMath 环境（本机安装、官方镜像、WSL）迁移到本方案容器；
2. 在不同版本镜像（debian12/fedora36/alpine）之间迁移；
3. 全新部署（含数据目录规划）。

## 场景一：从官方 sagemath/sagemath 镜像迁移

官方镜像用户目录为 `/home/sage/`，本方案为 `/home/sage/work`。

```bash
# 1) 从旧容器导出数据
docker run --rm -v sagemath_old_data:/old:ro -v $PWD/export:/export:rw \
  alpine sh -c "cp -a /old/* /export/"

# 2) 将数据放入本方案数据目录
mkdir -p work
cp -a export/* work/

# 3) 启动本方案容器
./scripts/run.sh debian12

# 4) 验证 Notebook 可打开
docker exec sagemath-debian12 ls -la /home/sage/work
```

## 场景二：在本方案三个版本间迁移

数据目录结构一致（均为 `/home/sage/work`），直接换服务名即可，无需改数据：

```bash
docker compose stop debian12
docker compose up -d fedora36        # 数据目录由 .env WORK_DATA 统一指向
```

注意：Fedora 36 (Sage 9.6) 与 Debian 12 (Sage 9.5) 的 `.sage` 缓存目录
（`/home/sage/.sage`）不共享，首次在新版本运行时内核/扩展需重新编译缓存。

## 场景三：全新部署到飞牛OS

```bash
# 在飞牛OS 终端
bash <(curl -sL https://raw.githubusercontent.com/ljm820/sagemath-docker-fnOS/main/fnos/deploy.sh)
# 或手动:
git clone https://github.com/ljm820/sagemath-docker-fnOS.git /vol1/1000/docker/sagemath
cd /vol1/1000/docker/sagemath
cp .env.example .env
vi .env                      # 设置 WORK_DATA、JUPYTER_TOKEN
./scripts/build.sh debian12
docker compose up -d debian12
```

## 数据规划建议（NAS）

- **工作区**：`/vol1/1000/docker/sagemath/work` —— Notebook、数据、实验结果
- **配置**：`.env`（不含密钥时建议纳入 git；含密钥则用 `.env.local` 并 gitignore）
- **备份**：对 `work/` 与 `.env` 做快照/Time Machine，容器本身无需备份（可随时重建）

## 迁移校验清单

- [ ] `sage --version` 输出目标版本
- [ ] 关键 Notebook 可在新容器打开并执行
- [ ] `work/` 数据在新容器内可读写（`chown 1000:1000`）
- [ ] 端口无冲突，`http://IP:8888/lab` 可访问
- [ ] Jupyter 令牌已更新（`.env` 中 `JUPYTER_TOKEN`）
