#!/usr/bin/env python3
# =============================================================================
# v3.0: 手动组装单层 docker-archive (docker load 兼容)
#
# 背景 (见 SESSION_SUMMARY 第 5/8 节):
#   - 沙箱无 Docker, podman 4.3.1 的 load/save 存在 gzip bug;
#   - 最终交付面向用户 Docker daemon, 需标准的 docker-archive。
#
# 原理:
#   config.json 的 rootfs.diff_ids 必须是 "sha256:<hex>" 格式
#   (v2.0 曾因写成裸 hex 导致用户 docker load 报 invalid diffID)。
#   diff_id = sha256(未压缩 layer tar)。
#
# 用法:
#   podman export <container> > layer.tar
#   python3 scripts/assemble-archive.py \
#       --layer layer.tar.gz \
#       --repo sagemath9.5_deb12_julab \
#       --tag latest \
#       --out sagemath9.5_deb12_julab_v3.0.tar.gz
#
# 说明:
#   --layer 传入的是已 gzip 压缩的层文件 (layer.tar.gz);
#   脚本会先解压计算 diff_id, 再与原 gzip 层一起打包。
# =============================================================================
import argparse
import gzip
import hashlib
import io
import json
import os
import tarfile
import tempfile
import time


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def ungzip_sha256(gz_path: str) -> str:
    """计算未压缩层的 sha256 (即 diff_id)。"""
    h = hashlib.sha256()
    with gzip.open(gz_path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def build_config(diff_id: str, size: int, created: str) -> dict:
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
        "history": [{"created": created}],
        "os": "linux",
        "rootfs": {"type": "layers", "diff_ids": [f"sha256:{diff_id}"]},
    }


def main() -> None:
    ap = argparse.ArgumentParser(description="assemble single-layer docker-archive")
    ap.add_argument("--layer", required=True, help="gzip-compressed layer file")
    ap.add_argument("--repo", required=True, help="image repository name")
    ap.add_argument("--tag", default="latest", help="image tag")
    ap.add_argument("--out", required=True, help="output archive path")
    ap.add_argument("--size-bytes", type=int, default=None,
                    help="uncompressed layer size (optional, for manifest)")
    args = ap.parse_args()

    created = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    print(f"[1/3] computing diff_id from gzipped layer {args.layer} ...")
    diff_id = ungzip_sha256(args.layer)
    print(f"      diff_id = sha256:{diff_id}")

    if args.size_bytes is None:
        with gzip.open(args.layer, "rb") as f:
            # seek to end in streaming fashion
            size = 0
            while f.read(1024 * 1024):
                size += 1024 * 1024
            # not exact; better pass --size-bytes
        print(f"      (approx uncompressed size ~{size} bytes)")
    else:
        print(f"      uncompressed size = {args.size_bytes} bytes")

    cfg = build_config(diff_id, args.size_bytes or 0, created)
    config_json = json.dumps(cfg, indent=2)
    config_digest = hashlib.sha256(config_json.encode()).hexdigest()

    manifest = [
        {
            "Config": f"{config_digest}.json",
            "RepoTags": [f"{args.repo}:{args.tag}"],
            "Layers": ["layer.tar.gz"],
        }
    ]
    manifest_json = json.dumps(manifest)

    print(f"[2/3] writing archive {args.out} ...")
    with tarfile.open(args.out, "w") as tf:
        cfg_bytes = config_json.encode()
        info = tarfile.TarInfo("manifest.json")
        info.size = len(manifest_json)
        tf.addfile(info, io.BytesIO(manifest_json.encode()))

        info = tarfile.TarInfo(f"{config_digest}.json")
        info.size = len(cfg_bytes)
        tf.addfile(info, io.BytesIO(cfg_bytes))

        info = tarfile.TarInfo("layer.tar.gz")
        info.size = os.path.getsize(args.layer)
        with open(args.layer, "rb") as f:
            tf.addfile(info, f)

    print(f"[3/3] done -> {args.out} ({os.path.getsize(args.out)} bytes)")
    print(f"      config digest = sha256:{config_digest}")
    print(f"      layer gzip    = {os.path.getsize(args.layer)} bytes")
    print(f"      docker load   = docker load -i {args.out}")


if __name__ == "__main__":
    main()
