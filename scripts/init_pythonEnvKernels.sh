#!/bin/sh
# =============================================================================
# init_pythonEnvKernels.sh
# 在 JupyterLab 启动之后执行：扫描 /opt 下所有含 "env" 的 python 环境
# （如 /opt/sci-env、/opt/test-env），用各环境自身的 python 在 $HOME 用户目录下
# 注册为 Jupyter kernel（ipykernel install --user）。
#
# 设计要点：
#   - 仅用 --user 注册到 $HOME/.local/share/jupyter/kernels/，不改系统级路径
#   - 带 FLAG 守卫：仅首次执行，容器重启不重复注册
#   - 不接管 entrypoint、不 exec "$@"、不修改 Terminal 默认 shell（保持镜像原状）
#   - 注册后 JupyterLab 会实时监听到新 kernel，无需重启服务
# =============================================================================
set -e

FLAG=/var/lib/jupyter-kernels/.initialized

if [ -f "$FLAG" ]; then
  echo "[init-env-kernels] 已初始化，跳过 kernel 注册（删除 $FLAG 可强制重扫）。"
  exit 0
fi

echo "[init-env-kernels] 首次执行：扫描 /opt 下含 'env' 的 python 环境..."

# ---------------------------------------------------------------------------
# 自定义 Launcher 图标注入（可选）
# 将自定义 logo 拷贝到每个已注册内核的 resources/ 目录，使图标在容器重建后
# 依然生效（避免手动改可写层、重建即丢的问题）。
#
# 资源放置位置（随 /opt 绑定挂载进入容器，重建不丢）：
#   首选：/opt/sci-env_32x32.png 与 /opt/sci-env_64x64.png（预生成 PNG，直接拷贝）
#   备选：/opt/sci-env_logo.svg（源矢量）+ 各环境自带 Pillow，运行时渲染为 PNG
# 两个都不存在时，跳过图标注入，内核仍正常注册。
# ---------------------------------------------------------------------------
ICON_SRC_PNG32="/opt/sci-env_32x32.png"
ICON_SRC_PNG64="/opt/sci-env_64x64.png"
ICON_SRC_SVG="/opt/sci-env_logo.svg"

apply_logo() {
  # $1 = 内核名（即 kernelspec 目录名）
  ks="$HOME/.local/share/jupyter/kernels/$1"
  res="$ks/resources"
  mkdir -p "$res"
  if [ -f "$ICON_SRC_PNG32" ] && [ -f "$ICON_SRC_PNG64" ]; then
    cp -f "$ICON_SRC_PNG32" "$res/logo-32x32.png"
    cp -f "$ICON_SRC_PNG64" "$res/logo-64x64.png"
    echo "[init-env-kernels]   已注入自定义图标(PNG) -> $res"
  elif [ -f "$ICON_SRC_SVG" ] && "$py" -c "import PIL" >/dev/null 2>&1; then
    "$py" - "$ICON_SRC_SVG" "$res" <<'PYEOF'
from PIL import Image
import sys
src, out = sys.argv[1], sys.argv[2]
img = Image.open(src).convert("RGBA")
img.resize((64, 64), Image.LANCZOS).save(f"{out}/logo-64x64.png")
img.resize((32, 32), Image.LANCZOS).save(f"{out}/logo-32x32.png")
print("icons rendered to", out)
PYEOF
    echo "[init-env-kernels]   已注入自定义图标(SVG->PNG) -> $res"
  else
    echo "[init-env-kernels]   未找到 logo 资源(/opt 下无 sci-env_32x32.png / sci-env_64x64.png / sci-env_logo.svg)，跳过图标注入。"
  fi
}

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
    # 注入自定义 Launcher 图标（失败不影响内核注册）
    apply_logo "$name" || echo "[init-env-kernels] 警告：$name 图标注入失败（不影响内核注册）"
  else
    echo "[init-env-kernels] 警告：$name 注册失败，请检查 $py 与 ipykernel"
  fi
done

[ "$found" -eq 0 ] && echo "[init-env-kernels] 未发现可用的 *env* python 环境。"
mkdir -p "$(dirname "$FLAG")"
touch "$FLAG"
echo "[init-env-kernels] 初始化完成，共注册 $found 个内核。"
