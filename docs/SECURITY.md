# 安全检测：NVIDIA SkillSpector

本项目集成 [NVIDIA SkillSpector](https://github.com/nvidia/skillspector) 对所有
脚本、文档与操作步骤进行安全扫描，评估风险评分（0-100）并给出安装/使用建议。

## 背景

SkillSpector 是 NVIDIA 开源的 AI Agent 技能安全扫描器，采用**两阶段检测**：

1. **静态分析**：正则 + Python AST + YARA，覆盖 68 种漏洞模式（提示注入、数据外泄、
   权限提升、供应链、危险代码执行、恶意软件签名、MCP 投毒等）；
2. **LLM 语义分析（可选）**：对上下文与意图做语义评估，过滤误报（需配置模型密钥）。

本项目采用 `--no-llm` 静态扫描，**代码完全本地分析，不上传第三方**。

## 快速使用

```bash
./scripts/security-scan.sh
```

脚本会：
1. 自动安装 `uv`（如缺失）；
2. 通过 `uv tool install` 安装 `skillspector`（Python 3.12，由 uv 托管）；
3. 对项目根目录执行静态扫描；
4. 产出 `docs/security/skillspector-report.md` 与 `.json`。

## 风险评分对照

| 评分     | 级别    | 建议         |
|----------|---------|--------------|
| 0-20     | LOW     | SAFE         |
| 21-50    | MEDIUM  | CAUTION      |
| 51-80    | HIGH    | DO NOT INSTALL |
| 81-100   | CRITICAL| DO NOT INSTALL |

`skillspector scan` 退出码：`0`=评分<=50（SAFE/CAUTION），`1`=评分>50（DO NOT INSTALL），
`2`=执行错误。

## 本仓库扫描结果

报告文件：`docs/security/skillspector-report.md`

当前推送版本基线扫描评分 **0/100（LOW / SAFE）**，剩余未处理问题 0 个。

### 审计过程（如实记录）

`skillspector` 面向 AI Agent skill 设计，而本项目是 Docker 部署工程，因此
对仓库的**原始扫描**会命中一批"部署工程正常写法"的误报。我们按以下流程处理：

1. **原始扫描**：命中 44 项发现，风险评分 100/100（CRITICAL）。主要包括：
   - `SC4` 已知漏洞依赖：`jupyterlab==4.2.5 / notebook==7.2.2 / jupyter-server==2.14.2`
     存在 OSV 记录的 CVE —— **真实问题**，已将三个依赖升级到已修复版本
     （jupyterlab 4.6.2 / notebook 7.6.1 / jupyter-server 2.20.0）后不再命中；
   - `PE3` 凭据访问：全部命中在文档/配置文件对 `.env`、Jupyter 令牌、GitHub PAT
     的**占位符说明**上，无任何凭据读取/外泄逻辑；
   - `TM1/TM2` 工具参数滥用/链式滥用：全部命中在 Dockerfile 的
     `apt/dnf/pip -y`、`rm -rf` 缓存清理、`&&` 链式 RUN 上，属标准构建写法；
   - `RP1` 未固定镜像：文档示例与脚本中的 `docker run`，实际标签已在
     `build.sh / run.sh / docker-compose.yml` 显式固定；
   - `RA2` 会话持久化：`fnos/sagemath.service` 为用户显式安装的可选自启单元；
   - `EA3` 范围蔓延：LICENSE 文件误判。

2. **人工逐条核实**后，将上述误报通过 `.skillspector-baseline.yaml` 纳入基线
   （每条都附有理由，见基线文件）。

3. **基线扫描**：仅报告新增问题，当前评分 **0/100 SAFE**。

> 升级依赖修复 CVE 是本项目对 SkillSpector 最有价值的落地动作——原始扫描帮助
> 发现了 3 个真实存在安全公告的 Python 包版本。

### 审计建议

后续每次变更后执行 `./scripts/security-scan.sh`：
- 若新增评分>0，先对照报告判断是否为新误报（补充基线）还是真实风险（修复）；
- 保持 `.skillspector-baseline.yaml` 与代码同步提交，便于审查。

## 误报抑制（Baseline）

若未来新增合法代码被误报，可生成基线并在扫描时抑制：

```bash
skillspector baseline . -o .skillspector-baseline.yaml --no-llm
skillspector scan . --no-llm --baseline .skillspector-baseline.yaml
```

## CI 集成

`.github/workflows/skillspector.yml` 在每次 push 时自动执行静态扫描，
上传 `report.sarif` 与 `report.md` 到 Actions Artifacts。

如需将扫描升级为发布门禁（如评分 >50 阻断合并），把 workflow 中 `|| true` 去掉
并让 exit code 生效；企业可用 GitHub Code Scanning 消费 SARIF。

## 可选：LLM 语义分析

```bash
export SKILLSPECTOR_PROVIDER=openai
export OPENAI_API_KEY=sk-...        # 你的密钥，仅本机环境变量
skillspector scan .                 # 不带 --no-llm 即启用语义分析
```

支持 openai / anthropic / bedrock / nv_build / 本地 Ollama 等，详见 SkillSpector README。

> 密钥只放在环境变量中，**切勿写入项目文件或提交到仓库**。
