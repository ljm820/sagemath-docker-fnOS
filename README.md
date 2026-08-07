# SageMath + JupyterLab Docker (飞牛OS / fnOS)

在飞牛OS（基于 Debian 12 的 NAS 系统）上，用 Docker 构建并运行 **SageMath + JupyterLab**
的完整方案。提供 **Debian 12 / Fedora 36（对应 RHEL 8.8）/ Alpine** 三种基础镜像的
SageMath 镜像版本，附带一键构建、运行、迁移、测试脚本，并集成
**NVIDIA SkillSpector** 对全部操作与代码进行安全扫描。

## 特性

- 三种基础镜像、三个 SageMath 版本矩阵
- **v3.0 新增**：
  - [修复] JupyterLab Launcher（Notebook/Console 栏）**缺失 sagemath 图标**问题
    （双内核全局注册 + 官方 logo 图标，详见 [docs/SCIENCE.md](docs/SCIENCE.md)）
  - [集成] 科学仪器数据分析环境（XRD / EDS / XAS），对齐
    [pyXRD_EDS_XAS_Env](https://github.com/ljm820/pyXRD_EDS_XAS_Env) v1 + torch(CPU)
  - [瘦身] 移除冗余大包（PySide6/open3d）并清理缓存，镜像再降约 30%
- 非 root 用户（`sage`，uid=1000）运行，方便 NAS 数据卷权限对齐
- `tini` 作为 PID 1 + compose `init: true`，信号处理正确
- JupyterLab 4 + SageMath 内核开箱即用，令牌鉴权
- **v2.1 新增**：多 Python 环境内核自动注册（`scripts/init_pythonEnvKernels.sh` 扫描 `/opt/*env*` 并注册为 Jupyter kernel，FLAG 守卫只跑一次）+ 自定义 Launcher 图标（navy 艺术 Logo，见 `assets/`）+ 修复 Terminal / SSH 打开十几秒自动退出的容器重启循环
- 一键脚本：`build.sh / run.sh / stop.sh / test.sh / security-scan.sh / push-images.sh`
- 飞牛OS 专用部署手册与 systemd 可选自启单元
- 集成 NVIDIA SkillSpector 安全扫描（静态分析 + 可选 LLM 语义分析）
- GitHub Actions 每次推送自动执行安全扫描并产出报告

## 版本

| 版本 | 内容 | Release |
|------|------|---------|
| v1.1 | SageMath 9.5 + JupyterLab（debian12 生产版，修复归档加载问题） | [v1.1](https://github.com/ljm820/sagemath-docker-fnOS/releases/tag/v1.1) |
| v2.0 | v1.1 + 科学仪器数据分析环境（XRD/EDS/XAS） | [v2.0](https://github.com/ljm820/sagemath-docker-fnOS/releases/tag/v2.0) |
| v2.1 | v2.0 + 多 Python 环境内核自动注册（sci-env venv）+ 自定义 Launcher 图标 + 修复 Terminal/SSH 自动退出 | [v2.1](https://github.com/ljm820/sagemath-docker-fnOS/releases/tag/v2.1) |
| **v3.0** | **v2.0 + 修复 Launcher 缺失 sagemath 图标 + 对齐 pyXRD_EDS_XAS_Env v1 + 体积瘦身约 30%** | [v3.0](https://github.com/ljm820/sagemath-docker-fnOS/releases/tag/v3.0) |

## 镜像矩阵

| 基础镜像 | 对应发行版生态 | SageMath | Python | 镜像 Tag | 推荐度 |
|----------|----------------|----------|--------|----------|--------|
| `debian:12-slim` | 飞牛OS 同源 (Debian 12) | 9.5（官方源 `python3-sage`） | 3.11 | `debian12-sage9.5` | **推荐（生产）** |
| `fedora:36` | RHEL 8.8 同期 | 9.6（`sagemath-standard`） | 3.10 | `fedora36-sage9.6` | 可用 |
| `alpine:3.20` | 最小体积 (musl) | 10.x（PyPI `sagemath-standard` 源码构建） | 3.12 | `alpine-sage10x-experimental` | 实验性 |

> **Alpine 说明**：SageMath 上游官方仅支持 glibc，不提供 musl 支持；PyPI 的
> `sagemath-standard` 也只有源码包。因此 Alpine 版本属于**实验性源码构建**，
> 耗时长、可能失败，生产环境请使用 Debian 12 版本。

## 目录结构

```
sagemath-docker-fnOS/
├── images/
│   ├── debian12/            # Debian 12 版 Dockerfile + 入口脚本 + pip 依赖 + 内核图标
│   ├── fedora36/            # Fedora 36 版 (含 EOL 源切换)
│   └── alpine/              # Alpine 实验版
├── scripts/                 # 构建/运行/停止/测试/安全扫描/推送/组装脚本
│                             #   + v2.1: init_pythonEnvKernels.sh / init-root.sh
├── tests/                   # 冒烟测试 (smoke.sh, smoke-sci.sh, math-check.sage ...)
├── fnos/                    # 飞牛OS 部署手册、一键部署脚本、systemd 单元
├── docs/                    # QUICKSTART / SCIENCE / PUBLISH / TESTING / SECURITY
│   ├── JupyterLab多环境内核注册与使用方案.md  # v2.1 多内核注册与图标完整方案
│   └── security/            # SkillSpector 扫描报告
├── assets/                  # v2.1 自定义 Launcher 图标资源 (PNG/SVG)
├── docker-compose.yml       # 三套服务编排
├── .env.example             # 环境配置模板
└── Makefile
```

## 快速开始（任意 Docker 主机）

### 获取 v3.0 镜像（推荐：ghcr.io 直接拉取）

```bash
docker pull ghcr.io/ljm820/sagemath-docker-fnos:v3.0
docker run -d -p 8888:8888 ghcr.io/ljm820/sagemath-docker-fnos:v3.0
```

浏览器访问 `http://<主机IP>:8888`，访问令牌（Jupyter Token）为 `sagemath`。

### 获取 v3.0 镜像（GitHub Release 分卷）

GitHub Release 单资产上限 2GB，v3.0 镜像压缩包按卷拆分为多个分卷。
下载 [v3.0 Release](https://github.com/ljm820/sagemath-docker-fnOS/releases/tag/v3.0)
下全部 `part_*` 分卷后：

```bash
cat sagemath9.5_deb12_julab_v3.0.tar.gz.part_00 sagemath9.5_deb12_julab_v3.0.tar.gz.part_01 \
  > sagemath9.5_deb12_julab_v3.0.tar.gz
sha256sum sagemath9.5_deb12_julab_v3.0.tar.gz   # 校验值见 Release 说明
docker load -i sagemath9.5_deb12_julab_v3.0.tar.gz
docker run -d -p 8888:8888 sagemath9.5_deb12_julab:latest
```

### 本地构建（源码方式）

```bash
cp .env.example .env
./scripts/build.sh debian12          # 构建镜像
./scripts/run.sh debian12            # 启动容器 (端口 8888)
```

浏览器访问 `http://<主机IP>:8888`，令牌见 `.env` 的 `JUPYTER_TOKEN`（默认 `sagemath`）。

飞牛OS 详细步骤见 `fnos/fnos-notes.md`；迁移与测试见 `docs/` 目录。

## v2.1：多 Python 环境内核注册与自定义 Launcher 图标

在一个 JupyterLab 里同时调用 **SageMath 系统环境** 与 **sci-env（/opt/sci-env venv）** 等多套 Python 3.11，Launcher 显示自定义图标，并修复 Terminal/SSH 打开十几秒自动退出的问题。

- 完整方案与排错：[`docs/JupyterLab多环境内核注册与使用方案.md`](docs/JupyterLab多环境内核注册与使用方案.md)（含 §13.4 终端自动退出踩坑、§11.6 图标自动注入）
- 启动后自动注册 `/opt/*env*` 为 Jupyter kernel（FLAG 守卫）：[`scripts/init_pythonEnvKernels.sh`](scripts/init_pythonEnvKernels.sh)
- 自定义图标资源（navy 艺术 Logo，PNG/SVG）：[`assets/`](assets/)
- 运行时编排示例（预构建镜像 + `/opt` 绑定挂载 + `exec jupyter lab` 为 PID1）：[`deploy/docker-compose.scienv.example.yml`](deploy/docker-compose.scienv.example.yml)

## 测试

```bash
./scripts/test.sh debian12           # 冒烟测试：版本/数学计算/脚本/Jupyter HTTP 200
./scripts/test-sci.sh                # v3.0 科学环境测试（含 Launcher 图标回归）
make test                            # 全部镜像
```

## 安全检测（NVIDIA SkillSpector）

```bash
./scripts/security-scan.sh           # 静态扫描，产出 docs/security/skillspector-report.md
```

报告与本仓库推送结果一致：风险评分 `0/100`，结论 **SAFE**。使用与解读见
`docs/SECURITY.md`。

## 发布到 GitHub

本仓库通过 PAT（Personal Access Token）推送到私人仓库
`https://github.com/ljm820/sagemath-docker-fnOS`，具体推送步骤见 `docs/PUBLISH.md`
（`.github/` 下已配置 SkillSpector 扫描的 CI 工作流）。

## 参考

- SageMath 官方项目：<https://github.com/sagemath/sage>
- SageMath 容器参考（JupyterLab 整合）：<https://github.com/CCcat8059/sagemath>
- SageMath 学习参考：<https://github.com/maxwellyu1024/sagemath_learning>
- 科学仪器环境参考：<https://github.com/ljm820/pyXRD_EDS_XAS_Env>
- NVIDIA SkillSpector：<https://github.com/nvidia/skillspector>

## 许可证

MIT License，详见 [LICENSE](LICENSE)。
