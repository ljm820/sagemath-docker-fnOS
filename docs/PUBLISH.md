# 发布指南（v3.0）

本仓库通过 GitHub **PAT**（Personal Access Token）推送到
`https://github.com/ljm820/sagemath-docker-fnOS`，并通过 **GitHub Release 分卷**交付
完整镜像，同时推送 **ghcr.io** 便于 `docker pull`。

> 本文所有涉及凭据的操作均为**手动可验证**；PAT 通过环境变量注入，**绝不写入**仓库文件。

## 1. 前置：构建验证

沙箱环境**无 Docker**（Docker CLI 返回 Docker daemon 不可用）。使用 **podman 4.3.1 +
buildah 1.28.2 + skopeo 1.9.3**（vfs storage driver）完成构建与验证；最终交付镜像为
**Docker 兼容 docker-archive**，已在用户 Docker 主机实测可 `docker load` 与运行。

```
# 构建（Debian 12 / SageMath 9.5，约 1-2 小时，下载依赖为主）
buildah bud -t ljm820/sagemath-fnos:debian12-sage9.5 images/debian12

# 冒烟测试（v3.0：含 Launcher 图标回归）
IMAGE=ljm820/sagemath-fnos:debian12-sage9.5 bash scripts/test-sci.sh

# 真实容器端到端
podman run -d -p 18889:8888 --user sage ljm820/sagemath-fnos:debian12-sage9.5
curl -s http://127.0.0.1:18889/  # JupyterLab HTTP 200
curl -s http://127.0.0.1:18889/api/kernelspecs | python3 -m json.tool
```

## 2. 导出与组装 docker-archive

podman 4.3.1 的 gzip docker-archive `load/save` 存在 `invalid tar header` bug，
v2.0 教训。因此 v3.0 采用**手动组装单层归档**（`scripts/assemble-archive.py`）：

```bash
# 1) 用临时容器导出根文件系统（覆盖容器挂载点）
CID=$(podman create ljm820/sagemath-fnos:debian12-sage9.5)
podman export --overwrite -o /tmp/rootfs.tar "$CID"
podman rm "$CID"

# 2) 压缩为层（gzip 尽量调大压缩率）
gzip -9 < /tmp/rootfs.tar > /tmp/layer.tar.gz

# 3) 组装 docker 兼容归档（diff_id 自动带 sha256: 前缀）
python3 scripts/assemble-archive.py \
  --image ljm820/sagemath-fnos:debian12-sage9.5 \
  --tag sagemath9.5_deb12_julab:latest \
  --layer /tmp/layer.tar.gz \
  --output sagemath9.5_deb12_julab_v3.0.tar.gz

# 4) 校验归档自洽（diff_id 与 manifest 交叉验证 MATCH）
#    并在本机从归档重新加载回 image 验证可启动
python3 scripts/verify-archive.py sagemath9.5_deb12_julab_v3.0.tar.gz
```

## 3. 分卷与校验

GitHub Release 单资产上限 2GB。使用 **`split -n 2`**（均匀分 2 卷，避免余数产生
第 3 卷 1 字节文件）：

```bash
SIZE=$(stat -c %s sagemath9.5_deb12_julab_v3.0.tar.gz)
split -n 2 -d -a 2 sagemath9.5_deb12_julab_v3.0.tar.gz \
  sagemath9.5_deb12_julab_v3.0.tar.gz.part_

sha256sum sagemath9.5_deb12_julab_v3.0.tar.gz
sha256sum sagemath9.5_deb12_julab_v3.0.tar.gz.part_00
sha256sum sagemath9.5_deb12_julab_v3.0.tar.gz.part_01
```

> 注意：`split -d` 生成 `part_00`/`part_01` 等序号，v2.0 发布的是 `part_00`/`part_01`
> 命名。请按 **Release 实际资产名**生成合并命令，并在 Release 说明中给出一致步骤。

## 4. 创建 GitHub Release 并上传分卷

```bash
# 创建 Release（仓库默认分支 main，tag v3.0）
gh api repos/ljm820/sagemath-docker-fnOS/releases \
  -f tag_name=v3.0 \
  -f target_commitish=main \
  -f name="v3.0" \
  -f body='v3.0 更新：...' \
  --jq .id > /tmp/release_id.txt

# 逐卷上传（upload_url 中的 {?name,label} 替换为 ?name=...）
RELEASE_ID=$(cat /tmp/release_id.txt)
curl -X POST \
  -H "Authorization: Bearer $PAT" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @sagemath9.5_deb12_julab_v3.0.tar.gz.part_00 \
  "https://uploads.github.com/repos/ljm820/sagemath-docker-fnOS/releases/${RELEASE_ID}/assets?name=sagemath9.5_deb12_julab_v3.0.tar.gz.part_00"

curl -X POST \
  -H "Authorization: Bearer $PAT" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @sagemath9.5_deb12_julab_v3.0.tar.gz.part_01 \
  "https://uploads.github.com/repos/ljm820/sagemath-docker-fnOS/releases/${RELEASE_ID}/assets?name=sagemath9.5_deb12_julab_v3.0.tar.gz.part_01"
```

> Release 说明需包含：v3.0 变更摘要、镜像获取方式（ghcr.io 地址 + 分卷合并命令）、
> 完整包与各分卷 SHA-256、`docker load`/`docker run` 使用步骤。

## 5. 推送 ghcr.io（v3.0 新增，优先 skopeo）

ghcr.io 镜像地址：`ghcr.io/ljm820/sagemath-docker-fnos:v3.0`

```bash
export PAT='<ghcr 推送用 PAT: write:packages + delete:packages>'
bash scripts/push-ghcr.sh sagemath9.5_deb12_julab_v3.0.tar.gz v3.0

# 验证拉取
docker pull ghcr.io/ljm820/sagemath-docker-fnos:v3.0
# 或沙箱内
skopeo inspect docker://ghcr.io/ljm820/sagemath-docker-fnos:v3.0
```

## 6. 更新文档并提交推送

发布后同步更新并提交（提交时请勿包含真实 PAT）：

- `README.md` — 镜像矩阵、v3.0 Release 下载/ghcr 地址
- `docs/SCIENCE.md` — v3.0 校验清单（完整包/分卷 SHA-256）、验证结果
- `docs/PUBLISH.md` — 本文件
- `.monkeycode/docs/SESSION_SUMMARY.md` — 会话交接摘要
- `.github/workflows/skillspector.yml` — CI 扫描配置

```bash
git add -A && git commit -m "release: v3.0 ..."
git push https://x-access-token:${PAT}@github.com/ljm820/sagemath-docker-fnOS main
```

## 7. 安全扫描（SkillSpector）

```bash
./scripts/security-scan.sh
```

扫描结果（风险评分 0/100，SAFE）写入 `docs/security/skillspector-report.md`；
.github 工作流在每次 push 后自动执行并保持报告同步。
