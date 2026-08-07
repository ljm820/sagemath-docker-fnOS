#!/usr/bin/env python3
# =============================================================================
# v3.0-fix: 手动组装双层 docker-archive (docker load 兼容)
#
# 背景:
#   buildah 增量 commit 后, skopeo 重导出需重新压缩整个根文件系统
#   (容器存储仅保留未压缩 overlay 层), 磁盘 20G 无法承受。
#   本脚本复用原始压缩层 + 微型修复层, 手工组装标准 docker-archive。
#
# 用法:
#   python3 scripts/assemble-archive-2layer.py \
#       --layer1 /var/tmp/layer1.tar.gz \
#       --layer2 /var/tmp/layer2.tar.gz \
#       --repo sagemath9.5_deb12_julab \
#       --tag latest \
#       --out /var/tmp/sagemath9.5_deb12_julab_v3.0.tar.gz
#
# 说明:
#   两层 diff_id 均按未压缩层内容计算; 层顺序与 Docker 约定一致
#   (先基础层后增量层)。
# =============================================================================
import argparse
import gzip
import hashlib
import io
import json
import os
import tarfile
import time


def ungzip_sha256(gz_path: str) -> str:
    """计算未压缩层的 sha256 (即 diff_id)。"""
    h = hashlib.sha256()
    with gzip.open(gz_path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def build_config(diff_ids: list, created: str) -> dict:
    return {
        "architecture": "amd64",
        "config": {
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
                "LANG=C.UTF-8",
                "LC_ALL=C.UTF-8",
                "PYTHONUNBUFFERED=1",
                "SAGE_USER=sage",
                "SAGE_UID=1000",
                "JUPYTER_PORT=8888",
                "JUPYTER_TOKEN=sagemath",
                "WORK_DIR=/home/sage/work",
                "SCI_ENV=/opt/sci-env",
            ],
            "Cmd": ["jupyter-lab"],
            "Entrypoint": ["tini", "--", "/usr/local/bin/docker-entrypoint.sh"],
            "ExposedPorts": {"8888/tcp": {}},
            "WorkingDir": "/home/sage/work",
            "User": "1000",
        },
        "container_config": {},
        "created": created,
        "docker_version": "20.10.24",
        "history": [{"created": created} for _ in diff_ids],
        "os": "linux",
        "rootfs": {
            "type": "layers",
            "diff_ids": [f"sha256:{d}" for d in diff_ids],
        },
    }


def main() -> None:
    ap = argparse.ArgumentParser(description="assemble two-layer docker-archive")
    ap.add_argument("--layer1", required=True, help="gzip layer 1 (base)")
    ap.add_argument("--layer2", required=True, help="gzip layer 2 (incremental)")
    ap.add_argument("--layer3", required=False, help="gzip layer 3 (optional)")
    ap.add_argument("--repo", required=True, help="image repository name")
    ap.add_argument("--tag", default="latest", help="image tag")
    ap.add_argument("--out", required=True, help="output archive path")
    args = ap.parse_args()

    created = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    print(f"[1/4] computing diff_ids ...")
    d1 = ungzip_sha256(args.layer1)
    d2 = ungzip_sha256(args.layer2)
    diff_ids = [d1, d2]
    print(f"      layer1 diff_id = sha256:{d1}")
    print(f"      layer2 diff_id = sha256:{d2}")
    layer_paths = [args.layer1, args.layer2]
    if args.layer3:
        d3 = ungzip_sha256(args.layer3)
        diff_ids.append(d3)
        layer_paths.append(args.layer3)
        print(f"      layer3 diff_id = sha256:{d3}")

    cfg = build_config(diff_ids, created)
    config_json = json.dumps(cfg, indent=2)
    config_digest = hashlib.sha256(config_json.encode()).hexdigest()

    l_names = [os.path.basename(p) for p in layer_paths]
    manifest = [
        {
            "Config": f"{config_digest}.json",
            "RepoTags": [f"{args.repo}:{args.tag}"],
            "Layers": l_names,
        }
    ]
    manifest_json = json.dumps(manifest)

    print(f"[2/4] writing archive {args.out} ...")
    with tarfile.open(args.out, "w") as tf:
        info = tarfile.TarInfo("manifest.json")
        info.size = len(manifest_json)
        tf.addfile(info, io.BytesIO(manifest_json.encode()))

        info = tarfile.TarInfo(f"{config_digest}.json")
        info.size = len(config_json.encode())
        tf.addfile(info, io.BytesIO(config_json.encode()))

        for lpath, lname in zip(layer_paths, l_names):
            info = tarfile.TarInfo(lname)
            info.size = os.path.getsize(lpath)
            with open(lpath, "rb") as f:
                tf.addfile(info, f)

    print(f"[3/4] done -> {args.out} ({os.path.getsize(args.out)} bytes)")
    print(f"      config digest = sha256:{config_digest}")
    for p in layer_paths:
        print(f"      layer gzip    = {os.path.basename(p)} {os.path.getsize(p)} bytes")


if __name__ == "__main__":
    main()
