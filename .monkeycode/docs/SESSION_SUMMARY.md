# 会话交接总结 — SageMath+JupyterLab v2.0 镜像交付 (fnOS)

> 本文档供新会话环境快速恢复上下文，继续本项目。最后更新：2026-08-06。

## 1. 用户问题与需求

在飞牛OS（fnOS，基于 Debian 12 的 NAS）上，用 Docker 构建并运行
**SageMath 9.5 + JupyterLab** 环境。本次会话交付 v2.0 精简镜像，明确要求：

1. 核验 v2.0 镜像稳定运行，清理多余包/缓存后导出**最小 tar.gz**；
2. 在 `https://github.com/ljm820/sagemath-docker-fnOS` 的 **GitHub Release**
   分卷上传（单资产上限 2GB），标注 v2.0 版本；
3. 同时提供 **ghcr.io** 访问地址供下载核对；
4. 项目内比对修改，交付完整说明文档 / 操作步骤 / 代码更新 / 问题总结与最终方案。

## 2. 项目与最终交付状态

| 交付项 | 地址/值 |
|--------|---------|
| GitHub 仓库 | `https://github.com/ljm820/sagemath-docker-fnOS`（默认分支 `main`） |
| Release v2.0 | `https://github.com/ljm820/sagemath-docker-fnOS/releases/tag/v2.0` |
| ghcr 镜像 | `ghcr.io/ljm820/sagemath-docker-fnos:v2.0`（仓库名全小写） |
| 镜像 diff_id | `sha256:71005bdf3e0a6deef1baa08f0bac16b59d44e2fab539a441deaa5eb68f660460` |
| 镜像 config blob | `sha256:20a82a95d41d3765ddf6b5e4a753abcef037374a356322a67f10cf2126ee7184` |
| 完整包 sha256 | `bf293a618edd00df57eb7d5f627d77ccedf2a81e92cd8f05cefbd7b081c147de` |
| 分卷 part_aa | 1,083,058,951B, `ff9ecb142a...` |
| 分卷 part_ab | 1,083,058,952B, `a6fd52a5b5...` |
| CI | SkillSpector Security Scan `completed success`（最新提交 0d0ed9c） |

**Release 分卷资产（已上传，均为 uploaded）**：
- `sagemath9.5_deb12_julab_v2.0.tar.gz.part_aa` (1083058951)
- `sagemath9.5_deb12_julab_v2.0.tar.gz.part_ab` (1083058952)

**用户侧使用步骤**：
```bash
cat ...part_aa ...part_ab > sagemath9.5_deb12_julab_v2.0.tar.gz
sha256sum sagemath9.5_deb12_julab_v2.0.tar.gz   # bf293a61...
docker load -i sagemath9.5_deb12_julab_v2.0.tar.gz
docker run -d -p 8888:8888 sagemath9.5_deb12_julab:latest   # Token: sagemath
# 或直接 docker pull ghcr.io/ljm820/sagemath-docker-fnos:v2.0
```

## 3. 镜像内容与验证结果

- 基础：Debian 12（bookworm），SageMath 9.5（系统 `/usr/bin/sage`），JupyterLab。
- 科学环境：独立 venv `/opt/sci-env`（Python 3.11），19 个科学包，作为 JupyterLab
  默认 `python3` 内核；`sagemath` 内核独立（双内核）。隔离保护 SageMath 9.5。
- 主要组件：numpy/scipy/pandas/sklearn/skimage/sympy、pymatgen==2025.10.7（固定版）、
  ase/crystal-toolkit/pymatviz/PyXplore(--no-deps)、hyperspy/rsciio/larch/pywbem、
  torch 2.13.0+cpu（CPU 版）、ovito（免费模块；ovito-pro 商业版未含）、
  pyarrow/deltalake、PySide6/open3d/hdf5plugin/llvmlite。
- 配置：Entrypoint `["tini","--","/usr/local/bin/docker-entrypoint.sh"]`、
  Cmd `["jupyter-lab"]`、User root、WorkingDir `/home/sage/work`、EXPOSE 8888/tcp、
  `JUPYTER_TOKEN=sagemath`。
- 全量验证通过：sage OK、19 包导入成功、双内核、JupyterLab HTTP 200、
  科学内核 nbconvert 端到端 `ALL_SCI_PACKAGES_OK 3.1`。

## 4. 体积优化过程（7.4GB → 2.17GB）

- 清理：apt lists / pip cache / `__pycache__`(2825) / tests(278) / .pyc / doc/man/info /
  静态库 `*.a`；`/opt/sci-env` 3.7G→3.1G，根 7.4G→6.4G。
- 保留大头（功能必需）：torch 696M、PySide6 647M、ovito 243M、hdf5plugin 181M、
  llvmlite 171M、pyarrow 149M、deltalake 105M。
- 单层：`buildah commit --squash` 磁盘满失败 → **手动单层 tar + gzip + 精确 diff_id
  sha256** 导出（`/tmp/sci2/export_single.py` + `assemble.py`）。

## 5. 关键问题与处理方案（重要经验）

1. **podman load 报 `invalid tar header`**（gzip docker-archive，exit 125）：
   podman 4.3.1 沙箱 bug，用户 Docker daemon（Go archive/tar）不受影响。
2. **podman load 手动单层镜像报 `invalid checksum digest format`**：podman 的
   "reuse blob" 校验 bug（v1.1 由 podman 自身 save 生成故成功）。换 **buildah 解压层 +
   容器内直接运行验证**（sage/19包/内核全通过）。
3. **`buildah commit` 打包 6.4G 未压缩层 ENOSPC**（磁盘 20G 极紧）：放弃本地镜像
   commit，改 **OCI 镜像布局 + curl 手动实现 Docker Registry v2 协议**直接推 ghcr：
   `POST /v2/<repo>/blobs/uploads/` 拿会话 → `curl -T`（流式，避免 `--data-binary`
   大文件 OOM）PUT layer/config → PUT manifest 打标签。layer 上传 201、blob 200 验证通过。
4. **upload URL 为相对路径**：`Location` 是 `/v2/...`，需拼 `https://ghcr.io` 前缀。
5. **仓库名大小写**：ghcr 要求全小写（`fnOS` → `fnos`）。
6. **【用户实测】`docker load` 报 `invalid diffID for layer 0: expected "71005bdf...",
   got "sha256:71005bdf..."`**：config.json 的 `rootfs.diff_ids` 缺 `sha256:` 前缀
   （写成了裸 hex）。layer 内容正确。**修复**：diff_ids 补前缀 → 重新组装 → 重分卷 →
   删除重传 Release 资产 → ghcr 更新 config blob + manifest（layer blob 不变）。
   教训：手工构造 docker-archive 时 `diff_ids` 必须是 `sha256:<hex>` 格式。
7. **`split -b` 余数产生第 3 卷（1 byte）**：改用 `split -n 2`（均匀 2 块）。
8. **curl 偶发空响应/307 重定向**：加 `-L` 跟随、`-w %{http_code}` 诊断重试。

## 6. 环境约束（新会话继续必需）

- 沙箱**无 Docker**，仅 podman 4.3.1 + buildah；镜像验证用 buildah 容器内运行。
- 磁盘 20G 极紧：导出/分卷/上传前需确认空闲 >5G；临时文件在 `/var/tmp`。
- GitHub push 需内联 token：`git push "https://x-access-token:${PAT}@github.com/ljm820/sagemath-docker-fnOS.git" HEAD:main`。
- PAT 存 `/tmp/opencode/gh/token2`（scopes 含 `write:packages` + `delete:packages`），
  严禁外泄/提交；`upload_github_repo.sh` 含敏感 token 已在 .gitignore 排除。
- `podman login ghcr.io -u ljm820` 已成功（密码=PAT）。

## 7. 关键文件与目录

| 路径 | 说明 |
|------|------|
| `images/debian12/Dockerfile` | v2.0 核心（venv/科学层/Qt/双内核） |
| `images/debian12/requirements-sci.txt` | 科学依赖（pymatgen 固定版） |
| `scripts/test-sci.sh`、`tests/smoke-sci.sh`、`tests/sci-kernel-test.ipynb`、`Makefile` | 一键冒烟测试 |
| `docs/SCIENCE.md` | v2.0 设计/组件/交付/问题总结（5 节） |
| `docs/PUBLISH.md` | Release 分卷 + ghcr 手动推送步骤 |
| `README.md` | 快速开始（ghcr/分卷两种方式） |
| `/workspace/sagemath9.5_deb12_julab_v2.0.tar.gz` | 最终完整包（2,166,117,903B） |
| `/workspace/sagemath9.5_deb12_julab_v2.0.tar.gz.part_*` | 分卷（Release 已上传） |
| `/var/tmp/layer-v2.0.tar.gz` | 纯层 gz（2,186,801,280B, 供重建镜像） |
| `/tmp/sci2/` | 组装/推送脚本（assemble.py、push_ghcr.sh、cfg2.json、manifest2.json） |

## 8. Git 提交记录（master = 远端 main）

- `0d0ed9c` fix: 修正镜像 config diffID 前缀 (sha256:), 重新分卷上传并更新校验值
- `0b7afe8` docs: v2.0 交付说明 (ghcr 镜像 / Release 分卷 / 问题总结与最终方案)
- `760ffbe` feat: v2.0 集成 XRD/EDS/XAS 科学分析环境
- `e44c8e7` docs: 交付修复版镜像部署文件（v1.1 修复归档加载问题）

## 9. 后续可优化方向（建议）

1. 将手动 OCI 布局 + curl registry 推送流程固化为脚本（`scripts/push-ghcr.sh`），
   入仓，避免每次手工构造。
2. 组装/导出脚本 `assemble.py` 入仓（当前在 `/tmp/sci2/`，会随沙箱消失），
   并补充 `diff_ids` 带 `sha256:` 前缀的单元校验。
3. 考虑将 19 包导入冒烟测试接入 GitHub Actions CI（当前只有 SkillSpector 扫描）。
4. 若需进一步瘦身：评估替换 PySide6/open3d 为按需；或基于已清理镜像做二轮 squash。
5. ghcr 镜像当前单层（2.19G blob），如需多 tag（latest/v2.0）可 PUT 第二个 manifest。
6. 用户反馈 fnOS 实测效果后，可将验证结论回填 `docs/SCIENCE.md`。

## 10. 交接下一步（新会话可直接执行）

- 读取本文档 + `docs/SCIENCE.md` + `docs/PUBLISH.md` + `git log --oneline -8`。
- 如需重建镜像：用 `/var/tmp/layer-v2.0.tar.gz` + `assemble.py`（先补 diff_ids 前缀校验）。
- 如需重推 ghcr：`bash /tmp/sci2/push_ghcr.sh config` + `bash /tmp/sci2/push_ghcr.sh manifest`。
- 大文件校验值优先以本表为准（Release body 与 docs 已同步）。
