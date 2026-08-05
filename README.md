# SageMath + JupyterLab Docker (飞牛OS / fnOS)

在飞牛OS（基于 Debian 12 的 NAS 系统）上，用 Docker 构建并运行 **SageMath + JupyterLab**
的完整方案。提供 **Debian 12 / Fedora 36（对应 RHEL 8.8）/ Alpine** 三种基础镜像的
SageMath 镜像版本，附带一键构建、运行、迁移、测试脚本，并集成
**NVIDIA SkillSpector** 对全部操作与代码进行安全扫描。

## 特性

- 三种基础镜像、三个 SageMath 版本矩阵
- **v2.0 新增**：科学仪器数据分析环境（XRD / EDS / XAS），详见 [docs/SCIENCE.md](docs/SCIENCE.md)
- 非 root 用户（`sage`，uid=1000）运行，方便 NAS 数据卷权限对齐
- `tini` 作为 PID 1 + compose `init: true`，信号处理正确
- JupyterLab 4 + SageMath 内核开箱即用，令牌鉴权
- 一键脚本：`build.sh / run.sh / stop.sh / test.sh / security-scan.sh / push-images.sh`
- 飞牛OS 专用部署手册与 systemd 可选自启单元
- 集成 NVIDIA SkillSpector 安全扫描（静态分析 + 可选 LLM 语义分析）
- GitHub Actions 每次推送自动执行安全扫描并产出报告

## 版本

| 版本 | 内容 | Release |
|------|------|---------|
| v1.1 | SageMath 9.5 + JupyterLab（debian12 生产版，修复归档加载问题） | [v1.1](https://github.com/ljm820/sagemath-docker-fnOS/releases/tag/v1.1) |
| **v2.0** | **v1.1 + 科学仪器数据分析环境（XRD/EDS/XAS）** | [v2.0](https://github.com/ljm820/sagemath-docker-fnOS/releases/tag/v2.0) |

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
│   ├── debian12/            # Debian 12 版 Dockerfile + 入口脚本 + pip 依赖
│   ├── fedora36/            # Fedora 36 版 (含 EOL 源切换)
│   └── alpine/              # Alpine 实验版
├── scripts/                 # 构建/运行/停止/测试/安全扫描/推送脚本
├── tests/                   # 冒烟测试 (smoke.sh, math-check.sage, test-suite.py)
├── fnos/                    # 飞牛OS 部署手册、一键部署脚本、systemd 单元
├── docs/                    # QUICKSTART / MIGRATION / TESTING / SECURITY
│   └── security/            # SkillSpector 扫描报告
├── docker-compose.yml       # 三套服务编排
├── .env.example             # 环境配置模板
└── Makefile
```

## 快速开始（任意 Docker 主机）

```bash
cp .env.example .env
./scripts/build.sh debian12          # 构建镜像
./scripts/run.sh debian12            # 启动容器 (端口 8888)
```

浏览器访问 `http://<主机IP>:8888`，令牌见 `.env` 的 `JUPYTER_TOKEN`（默认 `sagemath`）。

飞牛OS 详细步骤见 `fnos/fnos-notes.md`；迁移与测试见 `docs/` 目录。

## 测试

```bash
./scripts/test.sh debian12           # 冒烟测试：版本/数学计算/脚本/Jupyter HTTP 200
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
- NVIDIA SkillSpector：<https://github.com/nvidia/skillspector>

## 许可证

MIT License，详见 [LICENSE](LICENSE)。
