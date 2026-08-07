# JupyterLab 多 Python 环境内核注册与使用完整方案

> **版本：v2.1（整合版）** · 更新于 2026-08-08 · 整合本会话全部历史：内核注册、图标生成、Tab 键修复、root 启动访问、PATH 假象排查、自动注册脚本、**Issue A（Terminal/SSH 打开十几秒自动退出）**、**Issue B（Launcher 图标替换失败）**。

> 场景：远程 Linux（Debian 12）上 Docker 容器运行 SageMath 的 JupyterLab（8888 端口）。
> 容器内有两套 Python 3.11 环境：
> - **sagemath 环境（系统环境）**：`/usr/bin/python3`（python3.11），装有 SageMath 9.5、numpy 1.24.2、scipy 1.10.1、JupyterLab 4.6.2
> - **sci-env 环境（venv）**：`/opt/sci-env/bin/python`，装有 numpy 2.4.6、scipy 1.17.1、pandas 3.0.5、torch 2.13.0+cpu、pymatgen 等大量科学计算包
>
> 目标：在一个 JupyterLab 中自由调用两套环境；Launcher（Notebook 栏与 Console 栏）显示图标；新建 .ipynb 的 Select Kernel 中可选 sci-env；环境间包与版本互不污染；稳定、高效、可靠、可持久化。

---

## 0. 版本与变更记录（v2.1）

| 版本 | 日期 | 关键内容 |
|------|------|----------|
| v1.0 | 早期 | 基础：sci-env 内核注册（`ipykernel install --user`）、环境隔离验证、PATH 假象排查、Launcher 图标理论 |
| v1.x | 中期 | 自定义 Logo 生成（sagemath 艺术字「S」/ sci-env 综合 Logo 的 AI 生成 Prompt）、Tab 键补全修复、root 启动访问 |
| v2.0 | — | 一键/自动注册脚本 `init_pythonEnvKernels.sh`（FLAG 守卫、扫描 `/opt/*env*`、`--user` 注册）固化进部署 |
| **v2.1** | 2026-08-08 | **整合本会话全部历史**：① Issue A 修复——Terminal/SSH 打开十几秒自动退出（`compose` 中 `sh -c "jupyter & ..."` 使 `sh` 成 PID1、`jupyter` 为后台作业，容器重启循环端掉所有会话；改为 `exec jupyter lab` + `( sleep 15 && 脚本 ) &`）；② Issue B 修复——Launcher 图标替换失败（JupyterLab 4 只认 `resources/logo-32x32.png`+`logo-64x64.png`，手动改根目录 `logo-svg.svg` 无效且重建即丢；将图标注入固化进 `init_pythonEnvKernels.sh` 的 `apply_logo()`，随 `/opt` 绑定挂载重建不丢）；③ 补 §13.4 踩坑节、§11.6 自动注入节，并更新 docker-compose 示例 |

> 配套交付物（与本方案一并随 v2.1 入库）：`docker-compose.yml`、`docker-compose.kernel-autoregister.example.yml`、`docker-compose.root-access.example.yml`、`init_pythonEnvKernels.sh`（含 `apply_logo`）、`init-root.sh`、图标资源 `sci-env_32x32.png` / `sci-env_64x64.png` / `sci-env_logo.svg`。

---

## 1. 结论先行（3 句话看懂方案）

1. **不需要装 conda**。conda 的隔离本质 = 「独立解释器 + 独立 site-packages」，你的 `/opt/sci-env` venv 已经具备同等隔离，缺的只是"告诉 Jupyter 这个解释器存在"。
2. Jupyter 识别环境靠 **kernelspec（内核注册表）**。注册后，Launcher 的 Notebook/Console 栏、Notebook 的 Kernel → Change Kernel（Select Kernel）会自动出现该内核，无需任何插件。
3. 核心只有一条命令：`/opt/sci-env/bin/python -m ipykernel install --user --name sci-env --display-name "Python 3.11 (sci-env)"`，然后重启/刷新 JupyterLab 即可。

每个内核 = 一个独立操作系统进程、一个独立解释器、一套独立 site-packages。`numpy 1.24.2`（sagemath）与 `numpy 2.4.6`（sci-env）在同一 JupyterLab 中共存、互不干扰——这就是你要的"conda 式隔离"。

---

## 2. 为什么当前看不到 sci-env？（根因）

JupyterLab 启动内核时，只会在以下目录中查找内核定义（kernelspec）：

```
/usr/local/share/jupyter/kernels
/usr/share/jupyter/kernels
~/.local/share/jupyter/kernels
~/.ipython/kernels
```

当前 `/opt/sci-env` 虽然装了 `ipykernel 7.3.0`（你的 pip list 里有），但**从未注册 kernelspec**，所以 Jupyter 完全感知不到它 → Launcher 没有图标、Select Kernel 没有选项。

> 版本兼容性已确认：sci-env 的 `ipykernel 7.3.0` / `jupyter_client 8.9.1` 与 JupyterLab 4.6.2 服务端 `jupyter_client 8.9.1` 完全兼容，注册后可直接使用。

---

## 3. 前置检查（1 分钟）

在 JupyterLab 的 **Terminal**（或容器内 shell）中执行：

```bash
# 1) 确认系统环境能看到哪些内核（当前应只有 python3 / sagemath）
jupyter kernelspec list

# 2) 确认 sci-env 里有 ipykernel（应输出 7.3.0）
/opt/sci-env/bin/python -c "import ipykernel; print(ipykernel.__version__)"

# 3) 确认 JupyterLab 服务以哪个用户运行（决定用 --user 还是 --prefix，见第 4 步）
whoami
ps -eo user,cmd | grep -i jupyter | grep -v grep
```

> 关键点：**注册内核的用户必须与 JupyterLab 服务运行用户一致**，否则服务端读不到内核。若 Terminal 里 `whoami` 显示 `sage`，用 `--user`；若显示 `root`，用 `sudo --prefix=/usr/local`。

---

## 4. 核心步骤：注册 sci-env 为 Jupyter 内核

### 4.1 执行注册（二选一）

**方式 A（推荐，无需 root，JupyterLab 以 sage 用户运行）**

```bash
/opt/sci-env/bin/python -m ipykernel install --user \
    --name sci-env \
    --display-name "Python 3.11 (sci-env)"
```

- `--name sci-env`：内核唯一标识，即 kernelspec 目录名，会出现在 Select Kernel 与命令行里
- `--display-name`：Launcher 图标和 Select Kernel 里显示的名字，随意改，如 `"Python 3.11 (sci-env, 材料计算)"`
- `--user`：写入 `~/.local/share/jupyter/kernels/sci-env/`
- 命令中的解释器用的是 `/opt/sci-env/bin/python`，所以生成的 kernel.json 的 argv[0] 自动指向 venv 解释器——**内核跑的必然是 sci-env 环境**

**方式 B（全局注册，需要 root/sudo）**

```bash
sudo /opt/sci-env/bin/python -m ipykernel install \
    --prefix=/usr/local \
    --name sci-env \
    --display-name "Python 3.11 (sci-env)"
```

写入 `/usr/local/share/jupyter/kernels/sci-env/`，容器内所有用户可见。

### 4.2 验证注册

```bash
jupyter kernelspec list
```

预期输出（示例，路径按你实际）：

```
Available kernels:
  python3    /usr/local/share/jupyter/kernels/python3        ← sagemath 自带
  sci-env    /home/sage/.local/share/jupyter/kernels/sci-env ← 刚注册
```

查看生成的 kernel.json：

```bash
cat ~/.local/share/jupyter/kernels/sci-env/kernel.json   # 或 /usr/local/share/jupyter/kernels/sci-env/kernel.json
```

```json
{
  "argv": [
    "/opt/sci-env/bin/python",
    "-m",
    "ipykernel_launcher",
    "-f",
    "{connection_file}"
  ],
  "display_name": "Python 3.11 (sci-env)",
  "language": "python",
  "metadata": {
    "debugger": true
  }
}
```

字段说明：

| 字段 | 作用 |
|---|---|
| `argv[0]` | 内核启动的解释器，**必须是指向 venv 的绝对路径**，决定内核用哪套环境 |
| `{connection_file}` | 占位符，Jupyter 服务启动内核时自动替换为连接文件路径 |
| `display_name` | Launcher / Select Kernel 中显示的名字，可随时改，无需重注册 |
| `metadata.debugger` | 启用 JupyterLab 调试器（需 ipykernel ≥ 6，你已满足） |
| `env`（可选） | 自定义环境变量，如 `"env": {"LD_LIBRARY_PATH": "/opt/sci-env/lib"}`,用于特殊依赖场景 |

---

## 5. 生效与测试（Launcher / Notebook / Console / 切换 / 隔离性）

### 5.1 让 JupyterLab 生效

刷新浏览器即可生效；若 Launcher 仍不显示，重启 JupyterLab 服务：

```bash
# 视实际启动方式二选一
sudo systemctl restart jupyterlab      # 若用 systemd 管理
# 或在容器内找到 jupyter 进程后重启（常见于 sagemath 镜像）：
docker restart <容器名>                 # 在宿主机执行
```

### 5.2 测试 A：Launcher 出现图标

回到 JupyterLab 首页 Launcher：
- **Notebook 栏**：出现 `Python 3 (ipykernel)`（sagemath 默认）与 `Python 3.11 (sci-env)` 两个图标
- **Console 栏**：同样出现这两个图标

### 5.3 测试 B：新建 sci-env 内核的 Notebook，验证环境归属

Launcher → Notebook → 点 `Python 3.11 (sci-env)`，新建 notebook 后执行：

```python
import sys
print("executable :", sys.executable)          # 应为 /opt/sci-env/bin/python
print("version    :", sys.version)             # 3.11.x

import numpy, scipy, pandas
print("numpy  :", numpy.__version__)           # 应为 2.4.6
print("scipy  :", scipy.__version__)           # 应为 1.17.1
print("pandas :", pandas.__version__)          # 应为 3.0.5

import pymatgen, torch
print("pymatgen :", pymatgen.__version__)      # 2025.10.7
print("torch    :", torch.__version__)         # 2.13.0+cpu
```

全部输出对应 sci-env 的包版本，即内核与包均来自 sci-env，可自行调用。

### 5.4 测试 C：默认（sagemath）内核不受影响

Launcher → Notebook → `Python 3 (ipykernel)`，执行：

```python
import sys
print(sys.executable)                          # /usr/bin/python3
import numpy, scipy
print("numpy :", numpy.__version__)            # 1.24.2
print("scipy :", scipy.__version__)            # 1.10.1
from sage.all import factor
print(factor(2**128 + 1))                      # 验证 SageMath 正常
```

### 5.5 测试 D：已有 notebook 中切换内核（Select Kernel）

打开任意 .ipynb → 菜单 **Kernel → Change Kernel…**（JupyterLab 4.x 也叫 Select Kernel）→ 选择 `Python 3.11 (sci-env)`。

> 注意：切换内核 = 重启内核进程，当前内存中的变量会被清空，属于预期行为（每个内核是独立进程）。

### 5.6 测试 E：Console 栏使用 sci-env

Launcher → Console 栏 → `Python 3.11 (sci-env)` → 直接交互式执行：

```python
import sys; sys.executable                    # /opt/sci-env/bin/python
```

### 5.7 测试 F：隔离性硬验证

在两个内核里分别执行：

```python
import numpy
print(numpy.__file__)
```

- sagemath 内核输出：`/usr/lib/python3/dist-packages/numpy/__init__.py`
- sci-env 内核输出：`/opt/sci-env/lib/python3.11/site-packages/numpy/__init__.py`

路径不同 + 版本不同（1.24.2 vs 2.4.6）= 隔离成功。在任一环境 `pip install` 新包都不会影响另一个环境。

---

## 6. 生产化与持久化（容器重建不丢配置）

> 容器一旦重建，未固化在镜像/卷里的注册会丢失。推荐以下方式之一。

### 6.1 方式一：一键注册脚本（容器内可重复执行）

```bash
# 保存为 /opt/sci-env/register_kernels.sh
#!/usr/bin/env bash
set -euo pipefail

register() {
    local venv="$1" name="$2" display="$3"
    if [ ! -x "$venv/bin/python" ]; then
        echo "[SKIP] $venv 不存在"; return 0
    fi
    "$venv/bin/python" -m ipykernel install --user \
        --name "$name" --display-name "$display"
    echo "[OK] $display 已注册"
}

register /opt/sci-env sci-env "Python 3.11 (sci-env)"

jupyter kernelspec list
```

```bash
chmod +x /opt/sci-env/register_kernels.sh
bash /opt/sci-env/register_kernels.sh
```

### 6.2 方式二：写进 Dockerfile（重建镜像即自带）

```dockerfile
# 在原有 Dockerfile 末尾追加（基础镜像按你实际写的改，例如 sagemath/sagemath:9.5）
FROM sagemath/sagemath:9.5

# ……原有创建 /opt/sci-env 及安装包的命令……

# 注册 sci-env 为 Jupyter 内核（--prefix 写入镜像全局目录）
RUN /opt/sci-env/bin/python -m pip install --no-cache-dir ipykernel \
 && /opt/sci-env/bin/python -m ipykernel install --prefix=/usr/local \
      --name sci-env --display-name "Python 3.11 (sci-env)"
```

> 若镜像默认用户是非 root 的 sage：Dockerfile 里先 `USER root` 注册再切回原用户，或改用 `--user`（写入 /home/sage/.local，只要 home 有卷挂载即可持久）。

### 6.3 方式三：直接 commit 当前容器（最快，应急用）

```bash
docker commit <当前容器名> sagemath-sci-env:latest
# 之后用新镜像重新起容器（端口、卷挂载参数照抄原启动命令）
docker run -d -p 8888:8888 -v <你的数据目录>:/home/sage/work --name sagemath-sci sagemath-sci-env:latest
```

### 6.4 以后新增第三个环境（通用流程）

```bash
# 示例：新建 /opt/tf-env 并注册
python3 -m venv /opt/tf-env
/opt/tf-env/bin/pip install ipykernel jupyter_client
/opt/tf-env/bin/python -m ipykernel install --user \
    --name tf-env --display-name "Python 3.11 (tf-env)"
```

任何 venv/conda 环境，只需「安装 ipykernel + 注册 kernelspec」两步，即可出现在 Launcher 和 Select Kernel。

---

## 7. 可选：如果你之后想用真 conda

当前 venv 方案更轻、无需改造现有环境，**不建议为此重装 conda**。若未来确需 conda：

```bash
# 1) 安装 Miniconda
wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
bash /tmp/miniconda.sh -b -p /opt/miniconda3

# 2) 建环境并装 ipykernel
/opt/miniconda3/bin/conda create -y -n sci python=3.11
/opt/miniconda3/envs/sci/bin/python -m pip install ipykernel

# 3a) 手动注册（推荐，与 venv 方案完全一致，可控性最好）
/opt/miniconda3/envs/sci/bin/python -m ipykernel install --user \
    --name conda-sci --display-name "Python 3.11 (conda:sci)"

# 3b) 或自动发现所有 conda 环境（base 环境装 nb_conda_kernels）
/opt/miniconda3/bin/python -m pip install nb_conda_kernels
```

注意：`nb_conda_kernels` 只自动识别"装了 ipykernel 的 conda 环境"，**不识别普通 venv**——所以你现在用 venv 时，走 3a 手动注册（与第 4 步相同）。

---

## 8. 稳定性 · 性能 · 可靠性建议

1. **绝对路径解释器**：kernel.json 的 `argv[0]` 必须用 `/opt/sci-env/bin/python` 绝对路径，避免 PATH 漂移导致内核意外落到系统环境。
2. **包管理纪律**：每个环境只用**自己的 pip**（`/opt/sci-env/bin/pip install xxx`）。绝不交叉安装。sci-env 装包后，只需重启该内核（Kernel → Restart Kernel）即可生效，无需重启 JupyterLab。
3. **不要动系统环境的依赖**：sagemath-standard 9.5 强依赖 numpy 1.24 / scipy 1.10，系统环境升级 numpy/scipy 会破坏 SageMath——这正是需要隔离的原因。
4. **内存管理**：sci-env 含 torch、PySide6 等大包，import 时才占内存；同时开太多内核会吃内存。闲置内核用 **Kernel → Shut Down All Kernels** 释放，或设置 `c.ServerApp.shutdown_no_activities_timeout` 自动回收。
5. **内核异常排查**：内核连接失败/显示 dead 时：`jupyter kernelspec list` 确认注册；手动执行 `/opt/sci-env/bin/python -m ipykernel_launcher --help` 确认解释器可用；看服务日志 `docker logs <容器名>`。
6. **环境变量**：若 sci-env 依赖特殊 `LD_LIBRARY_PATH`/`PATH`，在 kernel.json 加 `"env"` 字段（见 4.2 表）。
7. **命令行批处理**：不经过 UI 也能用指定内核执行 notebook（sagemath 系统环境自带 nbconvert）：

```bash
jupyter nbconvert --to notebook --execute --inplace \
    --ExecutePreprocessor.kernel_name=sci-env run_me.ipynb
```

8. **版本兼容基线**（当前已满足）：ipykernel 7.3.0 ↔ jupyter_client 8.9.1 ↔ JupyterLab 4.6.2。未来升级时保持三者大版本一致。

---

## 9. 常见问题排查（FAQ）

| 现象 | 原因 / 处理 |
|---|---|
| Launcher 没有 sci-env 图标 | 先 `jupyter kernelspec list` 确认已注册；刷新浏览器；仍无则重启 JupyterLab 服务（5.1） |
| 注册用的用户与服务不一致 | `--user` 只写当前用户目录。确认 `whoami` 与服务用户一致，root 服务用 `sudo --prefix=/usr/local` |
| 内核显示但启动失败（kernel died） | 手动跑 `/opt/sci-env/bin/python -m ipykernel_launcher --help`；确认 sci-env 内 `ipykernel`、`jupyter_client` 存在；看 `docker logs` |
| 在 sci-env 内核里 import 不到 sage | 正常，隔离生效。如需调用 Sage，用 `subprocess` 调 `/usr/bin/sage`，不要混装 |
| 新装的包在内核里没有 | `/opt/sci-env/bin/pip install` 后重启该内核（不是重启 JupyterLab） |
| 想改名 / 删除内核 | 改名：改 kernel.json 的 `display_name`；删除：`jupyter kernelspec remove sci-env` |
| 容器重建后内核丢失 | 用第 6 节的 Dockerfile 固化或 commit 镜像 |
| 内核里 PATH/LD_LIBRARY_PATH 不对 | 在 kernel.json 增加 `"env"` 字段，如 `{"PATH": "/opt/sci-env/bin:/usr/bin:/bin"}` |

---

## 10. 快速参考（复制即用）

```bash
# ① 注册（JupyterLab 以 sage 用户运行）
/opt/sci-env/bin/python -m ipykernel install --user \
    --name sci-env --display-name "Python 3.11 (sci-env)"

# ② 验证
jupyter kernelspec list

# ③ 刷新浏览器 / 重启服务后，Launcher 与 Select Kernel 即可选 sci-env

# ④ 双环境版本对照
python3 -c "import numpy; print(numpy.__version__)"            # 1.24.2（sagemath）
/opt/sci-env/bin/python -c "import numpy; print(numpy.__version__)"  # 2.4.6（sci-env）
```

---

## 11. 环境命名、Logo 生成与 Launcher 图标替换

### 11.1 环境命名：推荐 `matsci`（Materials Science）

按本环境的功能全景提炼：**材料科学计算与表征分析套件（Materials Science & Characterization）**——涵盖：

| 能力域 | 承载包 |
|---|---|
| 晶体/原子结构建模与可视化 | pymatgen、pymatviz、ovito、spglib |
| X 射线谱学表征（XRD / XAS / XPS） | xraylarch、PyXplore、xraydb |
| 显微与多维信号分析 | hyperspy、rosettasciio、silx、fabio |
| 透射电镜/衍射模拟 | WPEM、pyFAI |
| AI / 机器学习 | torch、numba |

**推荐内核名（机器标识，kernel name）**：`matsci` —— 简短、小写、可作目录名、一眼可懂。
**推荐显示名（Launcher 显示）**：`Materials Science & Characterization (Python 3.11)`

备选命名：`matsci-xray`（强调 X 射线表征）、`specmat`（光谱+材料）、`materia`（拉丁词）、`crysviz`（晶体+可视化）。改名只需一次重注册（见 11.3），内核标识与显示名独立，随时可调。

### 11.2 生成综合 Logo 的 Prompt（v4 终版：仅升级 XRD 与 XAS，保留 v1 整体）

> 使用建议：中文版（与 v1 原 prompt 风格一致）直接复制即可；如果模型对中文理解不稳定，再回退用英文版。
>
> 历史版本：v1（最初版，简洁 prompt）→ v2（精确 XAS/XRD 特征版，引入 Excel 纸与底部引用）→ v3（视觉叙事流 + 完整 XRD mini-chart，整体改动较大）→ **本节 v4（严格回到 v1 框架，**只把 XRD 和 XAS 两段从"三角峰"与"平滑曲线"升级为可识别视觉，其余元素全部保留 v1 原文**）**。如果你按 v3 跑出来的结果与 v1 风格偏差太大，直接用本节 prompt 重跑即可。

#### 11.2.1 v4 调整说明（最小改动原则）

| 元素 | v1 原描述 | v4 处理 | 理由 |
|---|---|---|---|
| 圆形徽章 + 透明背景 | ✓ 保留 | 不动 | v1 已足够 |
| 八面体晶体球棍模型（深蓝 + 琥珀） | ✓ 保留 | 不动 | v1 已足够 |
| 左上 X 射线射入 | ✓ 保留 | 不动 | v1 已足够 |
| 底部神经网络节点圆点 | ✓ 保留 | 不动 | v1 已足够 |
| 3 色 + 扁平 + 无文字 + 无水印 | ✓ 保留 | 不动 | v1 已足够 |
| **XRD 衍射峰** | "尖锐三角峰的 XRD 衍射峰形" | **升级**为 stick pattern：至少 5 根细尖垂直竖线从基线突起、高度参差（典型多峰衍射谱），禁止画成单个孤立三角 |
| **XAS/XPS 吸收谱** | "平滑的 XAS/XPS 吸收谱曲线" | **升级**为典型 XANES/EXAFS 特征曲线：水平基线 → 垂直 edge jump → 2-3 个紧密 XANES 小振荡 → 振幅衰减的 EXAFS 阻尼振荡；明确禁止普通正弦波与简单锯齿线 |

> v4 不引入 Excel 网格纸、底部软件引用行、squircle 徽章、坐标轴框等元素——这是对 v3 的回退，因为 v1 原文里没有这些元素。XRD/XAS 仅做"视觉特征升级"，不改动构图骨架。

#### 11.2.2 v4 中文版（推荐主用，与 v1 原文同语言风格）

```
极简扁平风材料科学软件图标，256×256 圆形徽章，透明背景。中心是发光的晶体原子结构——八面体球棍模型（6 个原子球由直化学键连接，深海军蓝 #0C447C 与琥珀色 #EF9F27 交替排列，仅靠键角（30°/150°）呈现清晰立体的八面体，不靠明暗）。左上角一束细 X 射线（琥珀色，沿对角线指向中心）射入晶体，向右侧散射出两部分表征信号：

1. XRD 衍射棒图（位于晶体右上方）：不要画单个三角形。改为标准 XRD stick pattern——从一条短水平基线上竖起至少 5 根细尖的琥珀色垂直竖线，高度参差（最高的接近徽章半径的 1/3，最矮的约为最高的 1/5），间距大致均匀，模拟典型多峰衍射谱（如 100、002、101、102、110 一类峰位）。整组竖线读作"典型 XRD 多峰排列"，而非孤立三角峰。

2. XAS/XPS 吸收谱曲线（位于晶体右下侧）：单根连续白色线条，必须呈现典型 XANES/EXAFS 特征——起点水平基线 → 突然垂直向上跳跃（吸收边 edge jump）→ 紧跟 2-3 个紧密尖锐的 XANES 小振荡 → 过渡到 EXAFS 区，振幅逐渐衰减的一条平滑阻尼振荡。曲线必须能识别为 XAS 吸收谱，绝不能画成普通正弦波或简单锯齿线。

底部点缀几个由细线连接的神经网络节点圆点（深蓝小圆 + 琥珀细线），暗示 AI/深度学习。

风格要求：纯扁平设计、纯色填充、无渐变、无阴影、无文字、无字母、无水印；配色严格只用 3 种颜色（深海军蓝 #0C447C + 琥珀色 #EF9F27 + 白色）；几何形状清晰，每条轮廓线 2-3px 厚；在 64×64 像素下依然可辨识；专业科研软件图标质感。
```

#### 11.2.3 v4 英文版（备选，跨模型兼容）

```
Minimalist flat vector app icon for a materials science Jupyter kernel, 256x256, circular badge with soft rounded corners, transparent background.

Center: a glowing crystal atomic structure — an octahedral ball-and-stick model (6 atom spheres connected by straight bonds, alternating deep navy blue #0C447C and amber #EF9F27, reading as a clear 3D octahedron via bond angles about 30 and 150 degrees, NOT via shading).

Upper-left: a thin amber X-ray beam entering diagonally toward the crystal center. To the right of the crystal, scatter two distinct representation signals:

1. XRD stick pattern (upper-right of the crystal): DO NOT draw a single triangle. Draw a standard XRD stick pattern — at least 5 sharp thin amber vertical lines rising from a short horizontal baseline, of clearly different heights (the tallest about one third of the badge radius, the shortest about one fifth of the tallest), spaced roughly evenly, simulating a typical multi-peak diffraction pattern (e.g. 100, 002, 101, 102, 110). The group must read as a typical XRD multi-peak arrangement, not as an isolated triangle peak.

2. XAS/XPS absorption curve (lower-right of the crystal): a single continuous white stroke with characteristic XANES/EXAFS shape — flat horizontal baseline → sharp vertical edge jump upward → 2-3 tightly packed small sharp XANES wiggles → transition into a damped oscillation whose amplitude gradually decreases (EXAFS). The curve MUST be recognizable as an XAS absorption spectrum; do NOT draw a generic sine wave or simple zigzag.

Bottom: a few neural-network node dots (small navy circles) connected by thin amber lines, hinting at AI/deep learning.

Style rules: pure flat design, solid color fills only, no gradients, no shadows, no text, no letters, no watermark; strict 3-color palette (deep navy blue #0C447C + amber #EF9F27 + white); crisp geometric shapes with 2-3px stroke; clearly recognizable when downscaled to 64x64; professional scientific-software icon aesthetic.
```

#### 11.2.4 v4 矢量精修追加指令（追求 SVG 级几何精度时可加在末尾）

```
Pure geometry: every shape built from circles, rectangles, straight lines, smooth bezier curves only. Stroke widths between 2 and 3 pixels. Crystal octahedron uses bond angles about 30 and 150 degrees. The first peak of the damped XAS oscillation is roughly 1.5 times the height of the second peak. XRD stick lines are 1-2px wide with sharp pointed tops. X-ray beam, crystal center, and the highest XRD stick should share a common diagonal axis line for visual cohesion.
```

### 11.3 内核改名（sci-env → matsci，可选）

```bash
# 重新注册为新名字（显示名一并更新）
/opt/sci-env/bin/python -m ipykernel install --user \
    --name matsci \
    --display-name "Materials Science & Characterization (Python 3.11)"

# 删除旧内核
jupyter kernelspec remove sci-env

# 验证
jupyter kernelspec list
```

> 若不想改名，跳过本步，后续命令中的 `matsci` 一律换成 `sci-env` 即可。

### 11.4 替换 Launcher 图标（核心配置）

JupyterLab 4 自动加载内核目录下 `resources/logo-32x32.png` 与 `logo-64x64.png` 两个文件作为 Launcher/Select Kernel 图标，**无需任何插件**。步骤：

```bash
# 1) 创建资源目录
mkdir -p ~/.local/share/jupyter/kernels/matsci/resources

# 2) 把生成的 logo 缩放为 32/64 两个尺寸（用 sci-env 自带的 Pillow）
/opt/sci-env/bin/python - <<'EOF'
from PIL import Image
src = "/home/sage/work/matsci_logo.png"          # 改为你的生成图路径
out = "/home/sage/.local/share/jupyter/kernels/matsci/resources"
img = Image.open(src).convert("RGBA")
img.resize((64, 64), Image.LANCZOS).save(f"{out}/logo-64x64.png")
img.resize((32, 32), Image.LANCZOS).save(f"{out}/logo-32x32.png")
print("icons written to", out)
EOF

# 3) 确认文件就位
ls -l ~/.local/share/jupyter/kernels/matsci/resources/
```

`resource_dir` 默认自动推断为 kernelspec 目录下的 `resources/`，通常无需改动 kernel.json；如需显式声明，kernel.json 最终形态如下：

```json
{
  "argv": [
    "/opt/sci-env/bin/python",
    "-m",
    "ipykernel_launcher",
    "-f",
    "{connection_file}"
  ],
  "display_name": "Materials Science & Characterization (Python 3.11)",
  "language": "python",
  "metadata": {
    "debugger": true
  },
  "resource_dir": "/home/sage/.local/share/jupyter/kernels/matsci/resources"
}
```

### 11.5 生效与验证

```bash
# 内核与资源都在
jupyter kernelspec list
ls ~/.local/share/jupyter/kernels/matsci/resources/

# 直接请求图标 URL（容器内，返回 200 即生效）
curl -s -o /dev/null -w "%{http_code}\n" \
  http://localhost:8888/kernelspecs/matsci/logo-64x64.png
```

浏览器**硬刷新（Ctrl+Shift+R 清缓存）**，Launcher 的 Notebook/Console 栏即显示新图标；若仍为旧图标，重启一次 JupyterLab 服务（见 5.1）。容器重建后图标随内核一并丢失，同样用第 6 节的 Dockerfile 固化（把 icons 与 kernel.json 都放入镜像，或使用 commit 方式）。

### 11.6 用 init 脚本自动注入图标（推荐，容器重建不丢）

手动改 `kernels/<name>/logo-svg.svg` **不会生效**——JupyterLab 4 只认 `resources/logo-32x32.png` 与 `resources/logo-64x64.png`，且手动改动写在容器可写层，重建即丢。最稳的做法是让 `init_pythonEnvKernels.sh` 在注册内核后顺手把图标塞进 `resources/`：

**部署步骤：**

1. 把下面 3 个文件放进宿主机的 `/opt` 绑定挂载目录（即 `sagemath_scienv_opt/`，随容器重建不丢）：
   - `sci-env_32x32.png`（32×32 PNG，透明底）
   - `sci-env_64x64.png`（64×64 PNG，透明底）
   - `sci-env_logo.svg`（可选；若 PNG 缺失则用各环境自带 Pillow 从它渲染）
2. `init_pythonEnvKernels.sh` 已内置 `apply_logo()`：注册每个 `*env*` 内核成功后，自动 `mkdir resources/ && cp` 注入上述 PNG；PNG 缺失时回退到 SVG→PNG 渲染；两者皆无则跳过（不影响内核注册）。
3. 重建容器（或 `rm /var/lib/jupyter-kernels/.initialized` 后重跑脚本）使其生效；浏览器 **Ctrl+Shift+R 硬刷新**。

> 因为 `/opt` 是绑定挂载、FLAG 在可写层：重启（层保留）跳过脚本、图标仍在；重建（层丢弃、FLAG 消失）脚本重跑、图标重新注入。两种情况下图标都不丢。

---

## 12. 进阶排查：Launcher 显示了内核，但 notebook 仍跑系统 `/usr/bin/python`

> 典型现象：执行了 `ipykernel install`，Launcher 也出现了 `Python 3.11 (sci-env)` 图标；点击它新建/打开 notebook 后，里面 `which python` 仍是 `/usr/bin/python`、`numpy.__version__` 仍是 `1.24.2`（系统环境），没有切到 sci-env。下面按"先定位真相 → 再分原因修复"处理。

### 12.1 第一步永远看 `kernel.json` 的 `argv`（真相在这）

Jupyter 启动内核时，只认 kernelspec 目录里 `kernel.json` 的 `argv[0]`。**它指向哪个解释器，内核就跑哪个环境**。所以：

- `argv[0] == "/opt/sci-env/bin/python"` → 内核本身是对的，问题在"打开方式 / PATH 假象 / 旧 notebook"（见 12.4 的②③）。
- `argv[0] == "/usr/bin/python"` → 安装命令实际是用系统 python 跑的，这才是根因（见 12.4 的①）。

```bash
# 查看该内核的启动命令（按实际安装位置选其一）
cat ~/.local/share/jupyter/kernels/sci-env/kernel.json
cat /usr/local/share/jupyter/kernels/sci-env/kernel.json
```

### 12.2 诊断命令清单（一次性跑完）

```bash
# 1) Jupyter 实际扫到哪些内核、各自路径（注意有无重复/同名）
jupyter kernelspec list

# 2) 看 sci-env 的 argv 是否真指向 venv
cat ~/.local/share/jupyter/kernels/sci-env/kernel.json

# 3) 在"疑似错误"的 notebook 里跑，确认内核真身
import sys, numpy
print(sys.executable)        # 内核真身，必须是 /opt/sci-env/bin/python
print(numpy.__version__)     # 必须是 2.4.6（系统为 1.24.2）

# 4) 注意：!which python 可能是 PATH 假象，不要单独据此下结论
!which python                # 仅看 shell 子进程的 PATH 解析
!echo $PATH
```

> **关键判据**：`sys.executable` 才是内核真实使用的解释器；`!which python` 走的是 shell 子进程，继承内核环境变量，可能仍解析到 `/usr/bin/python`，属于**假象**，不代表内核跑错。

### 12.3 四大原因与对应修复

#### ① `--user` 装到了错误的用户 HOME，而 Jupyter 服务以另一用户运行（最常见）

`--user` 把 kernelspec 写到**执行安装命令那个用户**的 `$HOME/.local/share/jupyter/kernels`。若 Jupyter 服务以 **root** 运行、而你是在 `sage`（或 `sh`）终端里装的，root 的 Jupyter **默认不扫 `/home/sage/.local`**。结果 Launcher 里显示的可能是别处（系统级或默认）的同名/默认内核，它自然跑系统 python。

**修复 → 装成系统级，任何服务用户都能扫到：**

```bash
# 先清掉可能装错的旧项，避免重名冲突
jupyter kernelspec remove sci-env 2>/dev/null
jupyter kernelspec remove matsci  2>/dev/null

# 用 sci-env 的 python 装到 /usr/local（系统级）
/opt/sci-env/bin/python -m ipykernel install --prefix=/usr/local \
    --name sci-env \
    --display-name "Python 3.11 (sci-env)"
```

`--prefix=/usr/local` 后，kernelspec 落在 `/usr/local/share/jupyter/kernels/sci-env`，**`argv[0]` 必定是 `/opt/sci-env/bin/python`**（因为是它执行的安装），且所有用户运行的 Jupyter 都能读到。

#### ② 打开的是已有 `.ipynb`，其 metadata 记录的还是默认内核

点 Launcher 的 sci-env 图标只会**新建**一个 sci-env notebook；**已有 notebook 用自己记录的 kernel**（多半是默认 `python3`=系统）。看着"进去了还是系统 python"，其实开的是旧文件。

**修复：** 在 notebook 里 `Kernel → Change Kernel…` → 选 `Python 3.11 (sci-env)`；或确认新建时点是 sci-env 图标。切换内核 = 重启内核进程（变量清空，属预期）。

#### ③ 内核正确，但 `!which python` / `!pip` 指向系统 python（PATH 顺序问题，本案例即此）

**现象**：`kernel.json` 的 `argv[0]` 已是 `/opt/sci-env/bin/python`，notebook 里 `import numpy; numpy.__version__` 输出 `2.4.6`（sci-env 环境），包能正常导入 —— 说明**内核进程 100% 是 sci-env，完全正确**。但 `!which python` 仍显示 `/usr/bin/python`、`!pip --version` 显示系统 pip。

**根因**：内核进程由 `/opt/sci-env/bin/python` 启动，但它**继承的 `PATH` 环境变量**来自 Jupyter 服务（root/system）的启动环境，里面 `/opt/sci-env/bin` 要么没有、要么排在 `/usr/bin` 之后。当你在 notebook 里跑 `!which python` 或 `!python xxx.py` 或 `!pip install` 时，IPython 会起一个 **shell 子进程**，这个子进程用 `os.environ['PATH']`（即内核继承来的 PATH）去找 `python`，自然先找到 `/usr/bin/python`。

> 要点：`sys.executable` 永远等于内核真身（`/opt/sci-env/bin/python`），与 PATH 无关；`!which` 看的才是 PATH。两者不同步是**正常现象**，不代表内核跑错。

**是否需要修？**
- 如果你**只**在 notebook 单元格里写 Python 代码（`import`、运算），内核已经是对的，**不用修**。
- 但凡有以下需求就**必须**修 PATH：
  - 在 notebook 里跑 `!pip install xxx` 想装进 sci-env 环境（否则装到系统）
  - 在 notebook 里跑 `!python script.py` 想用 sci-env 解释器
  - 单纯想让 `!which python` 显示 sci-env 以免混淆

**修复方案（二选一，推荐方案甲）**：

**方案甲 · 包装脚本（推荐，保留原 PATH 不丢失）**

让内核启动前先把 `/opt/sci-env/bin` 插到 `PATH` 最前面，再用 `exec` 交给 sci-env 的 python。利用 bash 的 `$PATH` 展开，不会丢掉原有路径项。

```bash
# 1) 写包装脚本
cat > /opt/sci-env/bin/sci-env-kernel <<'EOF'
#!/bin/bash
# 把 venv 的 bin 目录插到 PATH 最前面，使 !which python / !pip 都解析到 sci-env
export PATH="/opt/sci-env/bin:${PATH}"
exec /opt/sci-env/bin/python -Xfrozen_modules=off -m ipykernel_launcher "$@"
EOF
chmod +x /opt/sci-env/bin/sci-env-kernel

# 2) 把 kernel.json 的 argv[0] 改成包装脚本（其余参数原样保留，用 python 改避免手改 JSON 出错）
/opt/sci-env/bin/python - <<'PY'
import json, pathlib
p = pathlib.Path("/usr/local/share/jupyter/kernels/sci-env/kernel.json")
d = json.loads(p.read_text())
d["argv"] = ["/opt/sci-env/bin/sci-env-kernel", "-f", "{connection_file}"]
p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
print("argv 已改为包装脚本：")
print(d["argv"])
PY
```

改完 `kernel.json` 形如（注意已无 `-Xfrozen_modules=off`，因为它被移进包装脚本的 `exec` 里了）：

```json
{
  "argv": ["/opt/sci-env/bin/sci-env-kernel", "-f", "{connection_file}"],
  "display_name": "Python 3.11 (sci-env)",
  "language": "python",
  "metadata": { "debugger": true, "supported_encryption": "curve" },
  "kernel_protocol_version": "5.5"
}
```

**方案乙 · 直接在 kernel.json 加 `env.PATH`（更轻量，但需写全 PATH）**

kernelspec 的 `env` 字段会在启动时**覆盖**同名环境变量。直接把完整 PATH 写出来，把 `/opt/sci-env/bin` 放最前：

```bash
/opt/sci-env/bin/python - <<'PY'
import json, pathlib
p = pathlib.Path("/usr/local/share/jupyter/kernels/sci-env/kernel.json")
d = json.loads(p.read_text())
d["env"] = {"PATH": "/opt/sci-env/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"}
p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
print("已写入 env.PATH")
PY
```

> 注意：`env` 是**覆盖**而非追加，所以右侧 PATH 字符串必须包含你容器里原本需要的全部目录（上面的 Debian 默认 PATH 通常够用；若服务有自定义 PATH，先 `echo $PATH` 抄下来再拼进去）。


#### ④ 有陈旧 / 同名 kernelspec 残留（曾改过名 v1→v4）

之前可能装过 `sci-env`、`matsci` 等多个内核，`jupyter kernelspec list` 若看到重复项，Launcher 可能绑错了。

**修复：** 清掉所有旧的再重装（见 12.3① 的清理命令）。

### 12.4 稳健修复流程（建议直接照做）

```bash
# 1. 清理所有残留
jupyter kernelspec list
jupyter kernelspec remove sci-env matsci 2>/dev/null

# 2. 系统级重装（关键：--prefix=/usr/local）
/opt/sci-env/bin/python -m ipykernel install --prefix=/usr/local \
    --name sci-env \
    --display-name "Python 3.11 (sci-env)"

# 3. 确认 argv 正确
cat /usr/local/share/jupyter/kernels/sci-env/kernel.json
#   应看到 "argv": ["/opt/sci-env/bin/python", "-m", "ipykernel_launcher", "-f", "{connection_file}"]

# 4. 重启 Jupyter 服务（不是重开标签页！）
#   docker 容器: docker restart <容器名>
#   前台运行: Ctrl-C 后重新 jupyter lab
```

重启后**新建**一个 notebook（点 Launcher 的 sci-env 图标），运行：

```python
import sys, numpy
print(sys.executable)        # 必须是 /opt/sci-env/bin/python
print(numpy.__version__)     # 必须是 2.4.6（系统为 1.24.2）
```

两行都对，问题解决。

### 12.5 一句话速查

Launcher 能显示 ≠ 内核跑对 python。**先看 `kernel.json` 的 `argv`**：八成是 `--user` 装到了 sage 的 HOME 而 Jupyter 服务（root）扫不到，导致实际启动的是系统默认内核。用 `/opt/sci-env/bin/python -m ipykernel install --prefix=/usr/local` 装系统级、清掉旧内核、重启服务即可。另外别被 `!which python` 骗了——**`sys.executable` 才是内核真身**。

### 12.6 本案例端到端步骤（内核已对、仅 `!which` 指向系统）

适用前提（你已满足）：`argv[0]` 是 `/opt/sci-env/bin/python`、notebook 能 `import` sci-env 的包、`numpy.__version__` 是 `2.4.6`，只是 `!which python` 显示 `/usr/bin/python`。

```bash
# ── 第 1 步：确认内核真身（在 notebook 里跑，预期如下）──
import sys, numpy
print(sys.executable)        # /opt/sci-env/bin/python  ← 内核正确
print(numpy.__version__)     # 2.4.6                    ← sci-env 环境
!which python                # /usr/bin/python           ← 仅 PATH 假象

# ── 第 2 步：写包装脚本（容器内执行，root 或能写 /opt/sci-env/bin 的用户）──
cat > /opt/sci-env/bin/sci-env-kernel <<'EOF'
#!/bin/bash
export PATH="/opt/sci-env/bin:${PATH}"
exec /opt/sci-env/bin/python -Xfrozen_modules=off -m ipykernel_launcher "$@"
EOF
chmod +x /opt/sci-env/bin/sci-env-kernel

# ── 第 3 步：把内核 argv 指向包装脚本 ──
/opt/sci-env/bin/python - <<'PY'
import json, pathlib
p = pathlib.Path("/usr/local/share/jupyter/kernels/sci-env/kernel.json")
d = json.loads(p.read_text())
d["argv"] = ["/opt/sci-env/bin/sci-env-kernel", "-f", "{connection_file}"]
p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
print("done ->", d["argv"])
PY

# ── 第 4 步：重启 Jupyter 服务（必须，内核配置改动要重载）──
#   docker 容器: docker restart <容器名>
#   前台运行:    Ctrl-C 后重新 jupyter lab

# ── 第 5 步：新建 sci-env notebook 验证 ──
import sys, numpy
print(sys.executable)        # /opt/sci-env/bin/python
print(numpy.__version__)     # 2.4.6
!which python                # 现在应为 /opt/sci-env/bin/python  ← 修复成功
!pip --version               # 现在应显示 sci-env 的 pip
```

**持久化提醒**：容器重建会丢 `kernel.json` 与包装脚本。固化方式任选：
- Dockerfile 固化（推荐）：把上述包装脚本写进镜像，且 `ipykernel install --prefix=/usr/local` 后追加一步用 `sed`/python 把 `argv[0]` 改成 `/opt/sci-env/bin/sci-env-kernel`；
- 或 `docker commit` 当前容器为新镜像；
- 或把包装脚本与改好的 `kernel.json` 通过 compose `volumes` 挂载进容器（bind mount 覆盖 `/usr/local/share/jupyter/kernels/sci-env/kernel.json` 与 `/opt/sci-env/bin/sci-env-kernel`）。

> 若你**不需要**在 notebook 里用 `!pip` / `!python`，可跳过第 2-3 步 —— 内核本身已正确，`sys.executable` 已是 sci-env，只 `!which` 看着别扭而已，不影响 Python 代码执行。

---

## 13. 容器首次启动时自动注册 `/opt/*env*` 为 Jupyter kernel（docker-compose 方案）

> 适用：镜像里已存在多个 venv（如 `/opt/sci-env`、`/opt/test-env`），希望容器**首次启动**时自动把它们全部注册成 Jupyter kernel 并显示在 Launcher，无需手动逐个 `ipykernel install`。脚本带"仅首次"守卫，重启不会重复注册。

### 13.1 初始化脚本 `init_pythonEnvKernels.sh`

脚本逻辑：遍历 `/opt/*env*/` 一级子目录 → 对每个含可执行 `bin/python` 且装了 `ipykernel` 的环境 → 用其自身的 python 注册内核（`--user`，写入 `$HOME/.local/share/jupyter/kernels/`）。**只做注册，不接管 entrypoint、不 `exec "$@"`、不改动 Terminal 默认 shell**——保持镜像原本状态。注册后 JupyterLab 会实时监听到新 kernel，无需重启服务。

```sh
#!/bin/sh
# init_pythonEnvKernels.sh
# 在 JupyterLab 启动之后执行：扫描 /opt 下所有含 "env" 的 python 环境，
# 用各环境自身的 python 在 $HOME 用户目录下注册为 Jupyter kernel（ipykernel install --user）。
#
# 设计要点：
#   - 仅用 --user 注册到 $HOME/.local/share/jupyter/kernels/，不改系统级路径
#   - 带 FLAG 守卫：仅首次执行，容器重启不重复注册
#   - 不接管 entrypoint、不 exec "$@"、不修改 Terminal 默认 shell（保持镜像原状）
#   - 注册后 JupyterLab 会实时监听到新 kernel，无需重启服务
set -e

FLAG=/var/lib/jupyter-kernels/.initialized

if [ -f "$FLAG" ]; then
  echo "[init-env-kernels] 已初始化，跳过 kernel 注册（删除 $FLAG 可强制重扫）。"
  exit 0
fi

echo "[init-env-kernels] 首次执行：扫描 /opt 下含 'env' 的 python 环境..."

found=0
for d in /opt/*env*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  py="$d/bin/python"
  [ -x "$py" ] || { echo "[init-env-kernels] 跳过 $name：无可执行 $py"; continue; }
  if ! "$py" -c "import ipykernel" >/dev/null 2>&1; then
    echo "[init-env-kernels] 跳过 $name：未安装 ipykernel"
    continue
  fi
  ver=$("$py" -c 'import sys; print("%d.%d" % (sys.version_info[0], sys.version_info[1]))' 2>/dev/null || echo "3.x")
  disp="Python $ver ($name)"
  echo "[init-env-kernels] 注册 $name -> $disp (--user, 安装到 $HOME)"
  if "$py" -m ipykernel install --user \
      --name "$name" \
      --display-name "$disp" >/dev/null 2>&1; then
    found=$((found + 1))
  else
    echo "[init-env-kernels] 警告：$name 注册失败，请检查 $py 与 ipykernel"
  fi
done

[ "$found" -eq 0 ] && echo "[init-env-kernels] 未发现可用的 *env* python 环境。"
mkdir -p "$(dirname "$FLAG")"
touch "$FLAG"
echo "[init-env-kernels] 初始化完成，共注册 $found 个内核。"
```

### 13.2 docker-compose.yml 关键改动（jupyter 先启动，再跑注册脚本）

本方案**不覆盖 entrypoint**，保留镜像原始 `tini → docker-entrypoint.sh` 链。关键是让 `jupyter lab` 经 `exec` 成为 **PID 1 前台进程**，内核注册脚本放进**独立的后台子 shell `( ... ) &`** 延迟执行（踩坑见 13.4）。

> ⚠️ 早期写法 `command: [jupyter lab ... && "/bin/sh", "-c", "init_pythonEnvKernels.sh"]` 语法不合法：`&&` 是 shell 操作符，不能出现在 compose 的列表元素里；且 `jupyter lab` 是阻塞进程，`&&` 要等它退出才会跑下一步，永远轮不到脚本。正确写法是用一条 `sh -c` 字符串承载整个链路（见下）。

```yaml
services:
  sagemath:
    image: sagemath9.5_deb12_julab:v1.1
    container_name: sagemath-scienv_deb12_v3.1
    restart: unless-stopped
    ports:
      - "36888:8888"
    environment:
      # 登录令牌, 请替换为你的强密码（command 中的 --ServerApp.token 优先生效）
      - JUPYTER_TOKEN=Go_123456
      - TZ=Asia/Shanghai
      # Terminal 默认用 bash（你已确认终端确实跑在 bash 下，保留）
      - SHELL=/bin/bash
    volumes:
      - /vol1/1000/_0.DataStation/_0.dockerStation/sagemath_lvscript_docker/workspace:/home/sage/work
      - /vol1/1000/_0.DataStation/_0.dockerStation/sagemath_lvscript_docker/sagemath_scienv_opt:/opt
      # 注：init_pythonEnvKernels.sh 随 /opt 这个 bind mount 进容器（位于 /opt/init_pythonEnvKernels.sh），
      #     无需单独再挂脚本；若想强制用宿主机最新版，可加：- /vol1/.../init_pythonEnvKernels.sh:/opt/init_pythonEnvKernels.sh:ro
    # 不覆盖 entrypoint：保留镜像原始 tini -> docker-entrypoint.sh 链
    # command：( 延迟注册脚本 ) & 独立后台跑；exec jupyter lab 成为 PID 1 前台保活
    command:
      - sh
      - -c
      - "( sleep 15 && /opt/init_pythonEnvKernels.sh ) & exec jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --ServerApp.token=Go_123456"
```

**要点**：
- `entrypoint` **不要**设置（删掉上一版的 `entrypoint: ["tini","--","/init-kernels.sh"]`），让镜像原始入口脚本生效。
- `exec jupyter lab ...` 把 wrapper `sh` 直接替换成 `jupyter` 作为 **PID 1**，信号与生命周期正确，容器随 jupyter 存活；`( sleep 15 && 脚本 ) &` 是独立子 shell 后台任务，即便失败也不拖垮容器。
- 注册脚本随 `/opt` 的 bind mount 进容器（路径 `/opt/init_pythonEnvKernels.sh`），`sh -c` 里直接调用即可；FLAG 守卫保证只注册一次。
- 注册脚本写入的是 `$HOME/.local/share/jupyter/kernels/`（`--user`）。由于 `jupyter lab` 与脚本都以同一用户（root，因 `--allow-root`）运行，`$HOME` 一致，Launcher 能直接看到。

### 13.3 验证与维护

```bash
docker compose up -d
sleep 20   # 等 jupyter 启动 + 脚本注册完成
# 进容器（任意方式）后：
jupyter kernelspec list          # 应看到 sci-env、test-env 等自动注册项
# 浏览器打开 JupyterLab，Launcher 的 Notebook/Console 栏出现对应图标

### 13.4 踩坑：Terminal / SSH 打开后十几秒自动退出、弹回 Launcher

**现象**：JupyterLab Launcher 打开 Terminal，确实跑在 bash 下、能输指令，但隔 ~10–15 秒 shell 自动退出、弹回 Launcher；用 SSH 进同一个容器也发生同样情况。

**根因**：上一版 `command` 是 `sh -c "jupyter lab ... & sleep 15 && 脚本 && wait"`。这条链路里 **`sh` 是 PID 1，而 `jupyter lab` 只是 `sh` 的一个后台作业（background job）**。容器能否存活完全取决于 `sh`：`wait` 只有在后台 `jupyter` 一直活着时才阻塞保活。

- 一旦 `jupyter` 因任何原因退出（它作为后台作业、非 PID 1，信号与生命周期都不标准，极易在 `sleep`→`script`→`wait` 的切换窗口里被带崩，或其自身启动期偶发崩溃），`wait` 立即返回、`sh -c` 退出、容器停止；
- `restart: unless-stopped` 又把容器拉起来 → 于是 **JupyterLab Terminal 和 SSH 会话被一起端掉**，回到初始 Launcher。
- 那个「十几秒」正好等于 `sleep 15` + 启动耗时，是 `wait` 真正接管保活、或 jupyter 在后台作业中撑不住的时间点。

> 为什么 Terminal 和 SSH **同时**掉？因为二者都是该容器进程树的子孙；容器一重启，整棵进程树被内核收掉，与具体是哪种登录方式无关。

**修复**（见 13.2 的 `command`）：让 `jupyter lab` 经 `exec` 成为 **PID 1 前台进程**，注册脚本放到独立的 `( sleep 15 && 脚本 ) &` 子 shell 里。这样只要 jupyter 自己活着，容器就活着，终端再不会被连锅端；后台子 shell 即便失败也不影响容器。

**验证（确认是否曾处于重启循环）**：
```bash
docker inspect -f '{{.RestartCount}}' sagemath-scienv_deb12_v3.1   # 修复前应持续上涨
docker events --since 30m --filter container=sagemath-scienv_deb12_v3.1  # 看是否频繁 die/start
# 修复后：开 Terminal、SSH 各挂十几分钟 idle + 连续输指令，均不自动退出
```
```

- **仅首次执行**：守卫文件 `/var/lib/jupyter-kernels/.initialized` 存在即跳过。普通 `docker restart` 不会重跑；`docker compose down` + `up`（重建容器）会重跑（文件系统重置）。
- **强制重扫**：进容器执行 `rm -f /var/lib/jupyter-kernels/.initialized && <重启服务>`。
- **新增环境后**：把新 venv 放到 `/opt/*env*`，删掉守卫文件并重启容器即可被自动注册。
- 若需自动注册的 kernel 在 notebook 内 `!which python` 也指向该环境，参见第 12.6 节的 PATH 修正（可在 13.1 脚本里对注册后的 `kernel.json` 追加 `env.PATH` 或包装脚本，按需扩展）。
