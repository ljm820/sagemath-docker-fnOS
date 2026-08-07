# Release v3.0 说明（草稿）

## 变更

- [修复] JupyterLab Launcher（Notebook/Console 栏）缺失 sagemath 图标问题
  - 双内核（sagemath + python3/sci-env）改为**全局注册**到
    `/usr/local/share/jupyter/kernels`，不再依赖用户家目录，数据卷挂载不影响
  - sagemath 内核补齐**官方 logo** 图标（取自 sagemath/sage 官方
    `ext_data/notebook-ipython`）
  - 移除运行时 `sage.repl.ipython_kernel install` 脆弱注册，内核构建期固化
- [集成] 科学仪器数据分析环境对齐 pyXRD_EDS_XAS_Env v1：
  - pymatgen 2025.10.7 + crystal-toolkit + pymatviz + PyXplore(--no-deps)
  - hyperspy[all] + rosettasciio + xraylarch + pywbem
  - torch (CPU) 保留；deltalake==1.5.1 保留（crystal_toolkit 模块级依赖）
- [瘦身] 移除冗余大包（PySide6 ~647M / open3d ~200M），
  清理 `__pycache__`/`.pyc`/tests/doc/man/静态库/pip cache/apt lists，
  镜像体积较 v2.0 再降约 30%
- [工具链] 新增 `scripts/assemble-archive.py`（docker-archive 组装，diff_id
  带 `sha256:` 前缀，避免 v2.0 invalid diffID 复现）、`scripts/push-ghcr.sh`
  （skopeo 推送 ghcr.io）、`scripts/gen-kernel-icons.py`（科学内核图标生成）

## 镜像获取

### 方式一：ghcr.io（推荐）

```bash
docker pull ghcr.io/ljm820/sagemath-docker-fnos:v3.0
docker run -d -p 8888:8888 ghcr.io/ljm820/sagemath-docker-fnos:v3.0
```

浏览器访问 `http://<主机IP>:8888`，令牌 `sagemath`。

### 方式二：Release 分卷

下载本 Release 下全部 `part_*` 分卷后合并：

```bash
cat sagemath9.5_deb12_julab_v3.0.tar.gz.part_00 sagemath9.5_deb12_julab_v3.0.tar.gz.part_01 \
  > sagemath9.5_deb12_julab_v3.0.tar.gz
sha256sum sagemath9.5_deb12_julab_v3.0.tar.gz
docker load -i sagemath9.5_deb12_julab_v3.0.tar.gz
docker run -d -p 8888:8888 sagemath9.5_deb12_julab:latest
```

## SHA-256 校验清单

| 文件 | SHA-256 |
|------|---------|
| 合并后完整 tar.gz | `6aa2aa110b2ba98bc3d5d94e7d294a61e285260d6891ce29e1c068ac8beb2966` |
| `.tar.gz.part_00` | `3958bae7a6bbdaf0909d3aaf1ea34d4b9c0e6353bb3a2015b7fe460c49b40e69` |
| `.tar.gz.part_01` | `5ee421ed444c9ad586299c0e5df5d4727410fb89ac26eee778656cfb3609ba15` |

> 分卷合并：`cat part_00 part_01 > 完整包`，合并后 sha256 应为
> `6aa2aa110b2ba98bc3d5d94e7d294a61e285260d6891ce29e1c068ac8beb2966`。

## 验证结果

- SageMath 9.5 启动正常
- 22 项科学包导入全部成功（numpy/scipy/pandas/torch 2.x+cpu/pymatgen/hyperspy/
  xraylarch/PyXplore 等）
- JupyterLab HTTP 200；科学内核端到端 `ALL_SCI_PACKAGES_OK`
- Launcher 内核列表含 sagemath/python3/sci-env，sagemath 官方图标 URL 200
  （v2.0 缺图标回归通过）
- 镜像双层 diff_id（基础层 + 入口脚本修复层）与 manifest 交叉校验 MATCH

## 使用

- 科学环境内核：`Python 3.11 (Science)` 或 `Python 3.11 (sci-env, 材料计算)`
- SageMath 内核：`SageMath 9.5`
- 详细文档：`docs/SCIENCE.md`、`docs/QUICKSTART.md`、`fnos/fnos-notes.md`
