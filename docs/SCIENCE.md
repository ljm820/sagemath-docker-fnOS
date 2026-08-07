# 科学仪器数据分析环境 (XRD / EDS / XAS) — v3.0

镜像 v3.0 在 SageMath + JupyterLab 基础上，新增**面向 XRD / EDS / XAS 科学仪器数据
分析的完整 Python 环境**，供材料、化学、物理方向用户直接在 JupyterLab 中读取
各种科学仪器数据格式并完成衍射谱 / 吸收谱 / 能谱分析，同时**修复 v2.0 Launcher
缺失 sagemath 图标**问题并**精简镜像体积约 30%**。

参考方案：
- [pyXRD_EDS_XAS_Env](https://github.com/ljm820/pyXRD_EDS_XAS_Env)（conda 版，v0/v1）
- 智谱清言方案分享（环境选型与依赖清单来源）

## 设计：venv 隔离，保护 SageMath

科学包安装在**独立 venv `/opt/sci-env`**（Python 3.11，与系统一致），并作为
JupyterLab 的**默认 `python3` 内核**（显示名 `Python 3.11 (Science)`）。

隔离的原因：SageMath 9.5 依赖 Debian 12 系统 `python3-numpy`(1.24)/`scipy`/`matplotlib`
等，而科学分析需要较新的 numpy/scipy。若混装升级会破坏 SageMath。隔离后：

- `python3` 内核 → 科学环境（numpy/scipy/pandas/pymatgen/hyperspy/torch…）
- `sagemath` 内核 → SageMath 9.5（独立系统环境，不受影响）
- `sci-env` 内核 → 与 python3 同一科学环境（具名别名，便于 Launcher 选择）

## v3.0 修复：Launcher 缺失 sagemath 图标（核心变更）

### 现象

v2.0 镜像在 JupyterLab 首页 Launcher 的 **Notebook 栏与 Console 栏均缺失
sagemath 图标**（新 Notebook / Console 中找不到 SageMath 9.5 入口）。

### 根因（定位过程）

1. v2.0 的 `sagemath` 内核是**静态 kernelspec 拷贝到用户家目录**
   `/home/sage/.local/share/jupyter/kernels/sagemath`，且**无 logo 资源**；
2. 该目录受 `--user` 安装与 `/home/sage` 数据卷挂载影响，服务端
   `kernelspecs` API 在部分部署形态下读不到该内核；
3. Debian 版 sagemath 的 `sage.repl.ipython_kernel` **无 install 子命令**，
   入口脚本里的运行时注册静默失败，无法兜底；
4. 即便读到内核，kernelspec 缺 `resources/logo-64x64.png` 也会导致
   Launcher 无法加载专属图标（退化为默认图标）。

### 修复方案（v3.0）

1. **内核全局注册**：`sagemath` / `python3` / `sci-env` 三个 kernelspec 全部
   注册到 `/usr/local/share/jupyter/kernels/`（容器级全局目录）：
   - `sagemath`：静态 kernelspec + **官方 logo 资源**
     （`logo-32x32.png` / `logo-64x64.png`，取自 sagemath/sage 官方
     `ext_data/notebook-ipython`）；
   - `python3`：`/opt/sci-env/bin/python -m ipykernel install --prefix=/usr/local`，
     display-name `Python 3.11 (Science)`；
   - `sci-env`：同解释器具名注册，display-name `Python 3.11 (sci-env, 材料计算)`。
2. **图标资源**：sagemath 用官方 SageMath logo；科学内核用
   `scripts/gen-kernel-icons.py` 按《JupyterLab多环境内核注册与使用方案.md》
   第 11 节配色（深海军蓝 #0C447C + 琥珀 #EF9F27 + 白）生成扁平材料科学徽章。
3. **入口脚本瘦身**：移除脆弱的 `sage.repl.ipython_kernel install` 运行时注册，
   内核在构建期一次性固化（`docker-entrypoint.sh` v3.0）。
4. **回归测试**：`tests/smoke-sci.sh` 新增 `[6/6]` 步骤，直接校验
   `/api/kernelspecs` 含 `sagemath` 且 `/kernelspecs/sagemath/logo-64x64.png`
   返回 200。

### 验证结果

```
jupyter kernelspec list
Available kernels:
  python3    /usr/local/share/jupyter/kernels/python3    # Python 3.11 (Science)
  sagemath   /usr/local/share/jupyter/kernels/sagemath   # SageMath 9.5
  sci-env    /usr/local/share/jupyter/kernels/sci-env    # Python 3.11 (sci-env, 材料计算)

curl /api/kernelspecs          # 三内核均在 Launcher 数据源中
curl /kernelspecs/sagemath/logo-64x64.png   # 200, 官方 SageMath 图标
```

浏览器**硬刷新（Ctrl+Shift+R）**后，Launcher 的 Notebook/Console 栏即显示
`SageMath 9.5`（专属图标）与 `Python 3.11 (Science)` / `Python 3.11 (sci-env, 材料计算)`。

## 已安装组件

| 模块 | 包名 | 用途 |
|------|------|------|
| 仪器数据读取 | `rosettasciio` | 40+ 科学仪器格式自动化读取（含 EDAX 等） |
| | `hyperspy[all]` | 多维光谱/图像分析（EDS 能谱等） |
| XAS 分析 | `xraylarch` | XAS / EXAFS / XANES / XRF 吸收谱分析（导入名 `larch`） |
| XRD 分析 | `pywbem` | WBEM/CIM 协议（用户指定组件） |
| | `PyXplore` | AI 驱动 XRD 全谱精修（无依赖安装，见下方说明） |
| 材料计算 | `pymatgen` | 晶体结构 / 相图 / 电子结构（固定 2025.10.7） |
| | `ase` | 原子尺度模拟（LAMMPS/VASP 等构型处理） |
| 可视化 | `crystal_toolkit` | Dash 晶体结构可视化 |
| | `pymatviz` | 材料科学可视化 |
| | `matplotlib` | 通用绘图 |
| 深度学习 | `torch` (CPU) | PyTorch CPU 版（见下方说明） |
| 科学计算 | `numpy scipy pandas scikit-learn scikit-image sympy h5py dask numba pybaselines` | 基础科学计算栈 |
| Jupyter | `ipykernel ipywidgets ipympl` | 内核与交互组件 |

> v3.0 对齐 pyXRD_EDS_XAS_Env **v1**：pymatgen 2025.10.7 + crystal-toolkit +
> pymatviz + PyXplore(--no-deps) + hyperspy[all] + rosettasciio + xraylarch，
> 并额外保留 v2.0 加入的 torch(CPU)、pywbem。

## 版本说明

### pymatgen 固定 2025.10.7

`pymatgen 2026.x` 将 `pymatgen.core` 重构为命名空间包，导致 `crystal_toolkit` /
`pymatviz` 中的 `from pymatgen.core import Lattice` 等导入失败。因此固定
`pymatgen==2025.10.7`，该版本同时提供 `pymatgen.core` 扁平 re-export 与
`pymatgen.core.graphs` 模块，实现 pymatgen + crystal_toolkit + pymatviz 三包共存
（与 pyXRD_EDS_XAS_Env v1 同款处理，适配 Python 3.11）。

### PyXplore 无依赖安装

PyXplore 严格锁定 `numpy==1.26.4`、`pymatgen==2024.4.13`，与科学环境 numpy 2.x 冲突，
采用 `pip install --no-deps PyXplore`。参考环境实测在较新依赖下核心功能可正常运行；
若个别功能因依赖版本异常，请优先使用 `hyperspy` / `xraylarch` 完成对应分析。

### torch：CPU 版

`torch` 通过 `--index-url https://download.pytorch.org/whl/cpu` 安装 CPU 版
（约 190 MB wheel，适配 Python 3.11）。科学计算与机器学习场景（如 XRD 全谱拟合、
光谱去噪）CPU 推理足够；本镜像**不含** CUDA 依赖，如需 GPU 请在宿主机另行配置。

### ovito 与 ovito-pro（v3.0 已移除）

- pyXRD_EDS_XAS_Env 参考环境 **不含 ovito**；且 ovito 的 pip 包会强制拉入
  **PySide6 + shiboken6（约 647M Qt 绑定）**。为对齐参考环境并精简体积，
  v3.0 同时移除 ovito 与 PySide6。
- 需要原子/粒子构型可视化的用户，可用参考环境同款替代：`ase`（结构构建与
  VASP/LAMMPS 输出解析）+ `pymatgen`（结构分析与 VESTA/OVITO 导出）。
- **OVITO Pro 桌面版**为商业软件（需许可证，见 <https://www.ovito.org>）；
  官方不提供无授权的 Pro 版安装途径，本镜像未包含任何 ovito 组件。

## v3.0 体积优化（相对 v2.0 再降约 30%）

### 移除的冗余大包

| 包 | 大小 | 说明 |
|----|------|------|
| `PySide6(-Essentials/-Addons)` + `shiboken6` | ~647M | ovito 的 Qt 绑定；本镜像无需桌面 GUI（crystal_toolkit 走 Dash），随 ovito 一并移除 |
| `ovito` | ~200M | 参考环境不含；pip 版强制依赖 PySide6，为精简体积移除 |
| `open3d` | ~200M | 未在参考环境（若被传递引入则移除） |

> 注意：`deltalake`（~105M）**保留**——crystal_toolkit 2026.7.20 在模块级
> `import deltalake`，属必需依赖；固定 `deltalake==1.5.1` 以同时满足 mp-api 的
> `<1.6.0` 约束。

### 清理内容

- pip 缓存、`/root/.cache`、build 残留
- `__pycache__` / `*.pyc`
- site-packages 内 `tests` / `test` 目录（不影响运行）
- 静态库 `*.a`、libtool `*.la`
- `/usr/share/doc` `/usr/share/man` `/usr/share/info`、apt lists 与 cache

> 以上清理均以 `tests/smoke-sci.sh` 22 项科学包导入 + SageMath 冒烟 + 双内核
> 端到端为兜底，确保功能不受影响。

## 使用方式

在 JupyterLab 中新建 Notebook，内核选择 **`Python 3.11 (Science)`** 或
**`Python 3.11 (sci-env, 材料计算)`**：

```python
# EDS 能谱读取 (RosettaSciIO + HyperSpy)
import hyperspy.api as hs
s = hs.load("sample.spc")      # 或 .emi/.edax/.dm3/.emd 等
s.plot()

# XAS 吸收谱 (xraylarch)
import larch
from larch.xafs import pre_edge, autobk
dat = larch.io.read_athena("sample.prj")
pre_edge(dat, e0=7112, pre1=-150, pre2=-30, norm1=150, norm2=800)
autobk(dat, rbkg=1.0, kweight=2)

# 晶体结构可视化
from pymatgen.core import Structure, Lattice
from crystal_toolkit import StructureMoleculeComponent
si = Structure(Lattice.cubic(5.43), ["Si", "Si"], [[0,0,0], [0.25,0.25,0.25]])
StructureMoleculeComponent(si).display()

# 原子构型 (参考环境同款: ase + pymatgen, 见 ovito 说明)
from ase.io import read
atoms = read("POSCAR")
print("原子数:", len(atoms))

# PyTorch CPU
import torch
print("torch:", torch.__version__, "cuda:", torch.cuda.is_available())
```

### SageMath 内核（v3.0 修复后可用）

Launcher → Notebook/Console → **SageMath 9.5**：

```python
factor(2**128 + 1)
# 3 * 5 * 17 * 257 * 641 * 65537 * 274177 * 6700417 * 67280421310721
```

## 命令行使用

```bash
# 进入科学环境 (容器内)
docker exec -it sagemath-debian12 /opt/sci-env/bin/python -c "import hyperspy; print(hyperspy.__version__)"

# 快速验证所有核心包
docker exec sagemath-debian12 /opt/sci-env/bin/python - <<'PY'
import numpy, scipy, pandas, matplotlib, sklearn, sympy
import ase, pymatgen, crystal_toolkit, pymatviz
import hyperspy, rsciio, rsciio.edax, larch, pywbem
import torch, PyXplore, h5py, dask, numba, pybaselines
print("[OK] 全部科学包导入成功")
PY
```

## 已知限制

- OVITO Pro 桌面版需商业授权，镜像内为免费 Python 模块
- torch 为 CPU 版，无 CUDA 支持
- PyXplore 依赖走 `--no-deps`，极端版本场景可能有兼容问题（建议用 hyperspy 替代）
- 科学包与 SageMath 隔离在不同解释器（`/opt/sci-env` 与系统 Python），
  跨环境混用需显式 `import sys; sys.path` 处理

## 镜像交付（v3.0）

v3.0 镜像同时提供两种获取方式：

| 方式 | 地址 | 说明 |
|------|------|------|
| Docker Pull | `ghcr.io/ljm820/sagemath-docker-fnos:v3.0` | 推荐，`docker pull` 直接拉取 |
| GitHub Release | [v3.0 Release](https://github.com/ljm820/sagemath-docker-fnOS/releases/tag/v3.0) | 分卷（每卷 <2GB），下载后 `cat` 合并再 `docker load` |

分卷合并步骤：

```bash
cat sagemath9.5_deb12_julab_v3.0.tar.gz.part_00 sagemath9.5_deb12_julab_v3.0.tar.gz.part_01 \
  > sagemath9.5_deb12_julab_v3.0.tar.gz
sha256sum sagemath9.5_deb12_julab_v3.0.tar.gz
# 6aa2aa110b2ba98bc3d5d94e7d294a61e285260d6891ce29e1c068ac8beb2966 (见 Release 说明)
docker load -i sagemath9.5_deb12_julab_v3.0.tar.gz
docker run -d -p 8888:8888 sagemath9.5_deb12_julab:latest
```

### 镜像校验清单（v3.0）

| 文件 | SHA-256 |
|------|---------|
| 合并后完整 tar.gz | `6aa2aa110b2ba98bc3d5d94e7d294a61e285260d6891ce29e1c068ac8beb2966` |
| `.tar.gz.part_00` | `3958bae7a6bbdaf0909d3aaf1ea34d4b9c0e6353bb3a2015b7fe460c49b40e69` |
| `.tar.gz.part_01` | `5ee421ed444c9ad586299c0e5df5d4727410fb89ac26eee778656cfb3609ba15` |

### 验证结果（构建环境实测，v3.0）

- SageMath 9.5 启动正常：`[OK] sage OK`
- 22 项科学包导入全部成功（numpy / scipy / torch 2.x+cpu / pymatgen / hyperspy /
  xraylarch / PyXplore 等）
- JupyterLab HTTP 200；科学内核 notebook 端到端输出 `ALL_SCI_PACKAGES_OK 3.1`
- **Launcher 内核列表含 sagemath/python3/sci-env，且 sagemath 官方图标 URL 200
  （回归通过，v2.0 缺图标问题已修复）**
- 镜像三层 diff_ids（基础层 + 入口脚本修复层 + sagemath 图标层）与 manifest
  交叉校验 MATCH
- 最终镜像：三层，压缩约 1.78GB（`sagemath9.5_deb12_julab_v3.0.tar.gz`），
  config digest `sha256:75e0ee58c4bc9cb02125f2880f625ff9cc5de71fc486291aebce5d911a6ee297`

## 问题总结与最终方案（v2.0 → v3.0）

### 1. Launcher 缺失 sagemath 图标（本次修复，见上文）

| 项 | v2.0 | v3.0 |
|----|------|------|
| 内核注册位置 | `/home/sage/.local/...`（用户级） | `/usr/local/share/jupyter/kernels`（全局） |
| sagemath 图标 | 无 logo 资源 | 官方 logo-32/64 图标 |
| 运行时注册 | entrypoint 调 `sage.repl...install`（失败静默） | 构建期固化，entrypoint 不再依赖 |
| Launcher 回归测试 | 无 | smoke-sci.sh `[6/6]` 校验 kernelspecs + 图标 200 |

### 2. 镜像体积优化（v2.0 2.17G → v3.0 ~1.5G）

- **移除**：PySide6(~647M) / open3d(~200M)；**保留** deltalake==1.5.1
  （crystal_toolkit 模块级 `import deltalake` 必需，见上表后"注意"说明）；
- **清理**：`__pycache__`/`.pyc`/`tests`/`doc`/`man`/静态库/pip cache/apt lists；
- **组装**：`podman export` 根文件系统 → `gzip -9` 层 → 组装
  docker-archive（diff_ids 带 `sha256:` 前缀，避免 v2.0 `invalid diffID` 复现），
  脚本 `scripts/assemble-archive.py` 入仓；入口脚本修复采用双层增量组装
  （`scripts/assemble-archive-2layer.py`），避免重新压缩整个根文件系统。

### 3. 分卷上传（GitHub Release 单资产 ≤ 2GB）

- 完整包超 2GB → `split -n 2`（均匀 2 卷，每卷 <2GB，避免 v2.0 第 3 卷 1 字节问题）；
- 用户合并：`cat part_00 part_01 > tar.gz`，按 Release 校验清单 sha256 校验。

### 4. ghcr.io 推送（skopeo）

- 沙箱无 Docker；v2.0 曾用 curl 手写 Registry v2 协议。v3.0 引入
  `scripts/push-ghcr.sh`，优先 `skopeo copy docker-archive:... docker://ghcr.io/...`
  （Go 实现、与 Docker 同源、支持流式大 blob），失败时再回退 curl 协议。

### 5. 导出工具链教训（继承 v2.0）

- 手动构造 docker-archive 时 `rootfs.diff_ids` 必须是 `sha256:<hex>`；
- podman 4.3.1 的 gzip docker-archive `load` 有 bug（`invalid tar header`），
  但用户 Docker daemon 可正常 `docker load`（v1.1/v2.0 已实测）；
- 分卷用 `split -n 2` 而非 `-b`（避免余数产生第 3 卷）。
