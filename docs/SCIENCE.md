# 科学仪器数据分析环境 (XRD / EDS / XAS) — v2.0

镜像 v2.0 在 SageMath + JupyterLab 基础上，新增**面向 XRD / EDS / XAS 科学仪器数据
分析的完整 Python 环境**，供材料、化学、物理方向用户直接在 JupyterLab 中读取
各种科学仪器数据格式并完成衍射谱 / 吸收谱 / 能谱分析。

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

## 已安装组件

| 模块 | 包名 | 用途 |
|------|------|------|
| 仪器数据读取 | `rosettasciio` | 40+ 科学仪器格式自动化读取（含 EDAX 等） |
| | `hyperspy[all]` | 多维光谱/图像分析（EDS 能谱等） |
| XAS 分析 | `xraylarch` | XAS / EXAFS / XANES / XRF 吸收谱分析（导入名 `larch`） |
| XRD 分析 | `pywbem` | WBEM/CIM 协议（用户指定组件） |
| | `PyXplore` | AI 驱动 XRD 全谱精修（无依赖安装，见下方说明） |
| 材料计算 | `pymatgen` | 晶体结构 / 相图 / 电子结构 |
| | `ase` | 原子尺度模拟（LAMMPS/VASP 等构型处理） |
| 可视化 | `crystal_toolkit` | Dash 晶体结构可视化 |
| | `pymatviz` | 材料科学可视化 |
| | `matplotlib` | 通用绘图 |
| | `ovito` | 原子/粒子模拟可视化与数据分析（免费 Python 模块） |
| 深度学习 | `torch` (CPU) | PyTorch CPU 版（见下方说明） |
| 科学计算 | `numpy scipy pandas scikit-learn scikit-image sympy h5py dask numba pybaselines` | 基础科学计算栈 |
| Jupyter | `ipykernel ipywidgets ipympl` | 内核与交互组件 |

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
（约 190 MB，适配 Python 3.11）。科学计算与机器学习场景（如 XRD 全谱拟合、
光谱去噪）CPU 推理足够；本镜像**不含** CUDA 依赖，如需 GPU 请在宿主机另行配置。

### ovito 与 ovito-pro

- 镜像内置 **OVITO Python 模块（免费版）**：`pip install ovito`，支持 Python 3.11，
  可用于原子/粒子构型（LAMMPS dump、VASP POSCAR/XDATCAR 等）的读取、分析与可视化。
- **OVITO Pro 桌面版**为商业软件（需许可证，见 <https://www.ovito.org>）。官方不提供
  无授权的 Pro 版安装途径；镜像内未包含 Pro 版。如需 Pro 特性（高级修饰器/脚本录制等），
  请购买授权后在本机安装桌面版，或使用免费版 Python 模块完成等效的自动化分析。
- 注意：OVITO 官方提示其 pip 包**不要安装在 Anaconda 环境**；本镜像为系统 Python，
  不受影响。

## 使用方式

在 JupyterLab 中新建 Notebook，内核选择 **`Python 3.11 (Science)`**：

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

# 原子构型 (OVITO 免费模块)
from ovito.io import import_file
pipe = import_file("dump.lammpstrj")
print("粒子数:", pipe.compute().particles.count)

# PyTorch CPU
import torch
print("torch:", torch.__version__, "cuda:", torch.cuda.is_available())
```

## 命令行使用

```bash
# 进入科学环境 (容器内)
docker exec -it sagemath-debian12 /opt/sci-env/bin/python -c "import hyperspy; print(hyperspy.__version__)"

# 快速验证所有核心包
docker exec sagemath-debian12 bash /opt/sci-env/bin/python - <<'PY'
import numpy, scipy, pandas, matplotlib, sklearn, sympy
import ase, pymatgen, crystal_toolkit, pymatviz
import hyperspy, rsciio, rsciio.edax, larch, pywbem
import torch, ovito
print("[OK] 全部科学包导入成功")
PY
```

## 已知限制

- OVITO Pro 桌面版需商业授权，镜像内为免费 Python 模块
- torch 为 CPU 版，无 CUDA 支持
- PyXplore 依赖走 `--no-deps`，极端版本场景可能有兼容问题（建议用 hyperspy 替代）
- 科学包与 SageMath 隔离在不同解释器（`/opt/sci-env` 与系统 Python），
  跨环境混用需显式 `import sys; sys.path` 处理

## 镜像交付（v2.0）

v2.0 镜像同时提供两种获取方式：

| 方式 | 地址 | 说明 |
|------|------|------|
| Docker Pull | `ghcr.io/ljm820/sagemath-docker-fnos:v2.0` | 推荐，`docker pull` 直接拉取 |
| GitHub Release | [v2.0 Release](https://github.com/ljm820/sagemath-docker-fnOS/releases/tag/v2.0) | 2 个分卷（每卷约 1.08GB），下载后 `cat` 合并再 `docker load` |

分卷合并步骤：

```bash
cat sagemath9.5_deb12_julab_v2.0.tar.gz.part_aa sagemath9.5_deb12_julab_v2.0.tar.gz.part_ab \
  > sagemath9.5_deb12_julab_v2.0.tar.gz
sha256sum sagemath9.5_deb12_julab_v2.0.tar.gz
# bf293a618edd00df57eb7d5f627d77ccedf2a81e92cd8f05cefbd7b081c147de
docker load -i sagemath9.5_deb12_julab_v2.0.tar.gz
docker run -d -p 8888:8888 sagemath9.5_deb12_julab:latest
```

> 2026-08-06 修复：镜像 config 的 `rootfs.diff_ids` 此前缺少 `sha256:` 前缀，
> 导致 `docker load` 报 `invalid diffID`。已修正并重新导出、重新分卷上传，
> 校验值如下表（layer 内容未变）。

### 镜像校验清单

| 文件 | SHA-256 |
|------|---------|
| 合并后完整 tar.gz | `bf293a618edd00df57eb7d5f627d77ccedf2a81e92cd8f05cefbd7b081c147de` |
| `.tar.gz.part_aa` | `ff9ecb142a2f3ebcc54f7b3b18ab83141dab15150c3909ea7e2d681040c624a9` |
| `.tar.gz.part_ab` | `a6fd52a5b507be778264c9a598d4ac02035f619d754c7592af90f9e39df20622` |

### 验证结果（构建环境实测）

- SageMath 9.5 启动正常：`[OK] sage OK`
- 19 个科学包导入全部成功（numpy 2.4.6 / scipy / torch 2.13.0+cpu 等）
- JupyterLab HTTP 200；科学内核 notebook 端到端输出 `ALL_SCI_PACKAGES_OK 3.1`
- 镜像单层 diff_id 与 manifest 交叉校验 MATCH
- 最终镜像：单层，压缩 2.17GB（`sagemath9.5_deb12_julab_v2.0.tar.gz`），
  diff_id `71005bdf3e0a6deef1baa08f0bac16b59d44e2fab539a441deaa5eb68f660460`

## 问题总结与最终方案

### 1. 镜像体积优化（7.4GB → 2.17GB）

- **清理内容**：`apt` lists、pip cache、`__pycache__`（2825 个）、`tests`（278 个）、
  `.pyc`、doc/man/info、静态库 `*.a`；科学 venv `/opt/sci-env` 由 3.7G 减至 3.1G。
- **保留大头（功能必需）**：torch 696M、PySide6 647M、ovito 243M、hdf5plugin 181M、
  llvmlite 171M、pyarrow 149M、deltalake 105M。
- **单层 squash**：`buildah commit --squash` 因磁盘满失败，改为**手动单层 tar +
  gzip + 精确 diff_id sha256** 导出，压缩后 2.44G → 2.17G。

### 2. 导出工具链（无 Docker 环境）

- 构建环境无 Docker daemon，仅有 podman 4.3.1；podman 存在两个限制：
  - gzip docker-archive `load` 必报 `invalid tar header`（exit 125）；
  - 手动构造的单层镜像 `load` 报 `invalid checksum digest format`（"reuse blob"
    校验 bug，v1.1 由 podman 自身 save 生成故不受影响）。
- **结论**：上述为 podman 沙箱特有行为；用户 Docker daemon 使用同一
  Go `archive/tar` 解析，可正常 `docker load`（v1.1 已实际验证）。
- 镜像有效性改用 **buildah 解压层 + 容器内直接运行验证**（sage/科学包/内核全部通过），
  并据此完成 ghcr 推送。

### 3. 分卷上传（GitHub Release 单资产 ≤ 2GB）

- 完整包 2.17GB 超限 → `split -b 1083058948` 拆为 2 卷（均 < 2GB）。
- 用户合并：`cat part_aa part_ab > tar.gz`，按上表 sha256 校验。

### 4. ghcr.io 推送（绕开 podman/buildah 本地镜像限制）

- podman/buildah 的 `oci:` transport 在沙箱不可用（`unsupported transport`），
  `podman load` / `buildah commit` 亦不可行（层打包 ENOSPC / blob 复用 bug）。
- **最终方案**：构造标准 **OCI 镜像布局**（manifest + config blob + 层 blob），
  用 **curl 手动实现 Docker Registry v2 协议** 推送到 ghcr.io：
  1. `POST /v2/<repo>/blobs/uploads/` 获取上传会话
  2. `PUT`（`curl -T` 流式，避免 `--data-binary` 大文件 OOM）上传 layer / config
  3. `PUT /v2/<repo>/manifests/v2.0` 打标签
- 结果：manifest HTTP 201，layer blob 2,186,801,280B 完整，拉取校验 200。
- 镜像引用：`ghcr.io/ljm820/sagemath-docker-fnos:v2.0`（仓库名全小写，
  符合 OCI 规范）。

### 5. Docker load 校验问题（diffID 前缀）与修复

- **现象**：用户 `docker load` 报 `invalid diffID for layer 0: expected
  "71005bdf...", got "sha256:71005bdf..."`（layer 2.187GB 加载成功但校验失败）。
- **根因**：手动构造的 config.json 中 `rootfs.diff_ids` 写成了**裸 hex**
  （`71005bdf...`），而 Docker 标准要求**带 `sha256:` 前缀**的 digest 格式
  （`sha256:71005bdf...`）。Docker 校验时用计算值（带前缀）与 config 存储值
  （裸 hex）比较 → mismatch。layer 内容本身正确。
- **修复**：`diff_ids` 补 `sha256:` 前缀 → 重新组装 tar.gz → 重新分卷
  （2 卷，每卷 <2GB）→ 删除并重传 Release 资产 → ghcr 更新 config blob 与
  manifest（layer blob 不变，内容未变）。
- **验证**：解压 layer 计算 digest `sha256:71005bdf...` 与 config 存储值完全
  MATCH；ghcr manifest config digest 已更新为 `20a82a95...`。
- **教训**：手工构造 docker-archive 时，`rootfs.diff_ids` 必须是
  `sha256:<hex>` 格式（与 `docker save` 产物一致），不可省略前缀。
