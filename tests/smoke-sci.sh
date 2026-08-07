#!/usr/bin/env bash
# =============================================================================
# v3.0 科学环境冒烟测试 (XRD / EDS / XAS)
# 用法: IMAGE=localhost/ljm820/sagemath-fnos:debian12-sage9.5 tests/smoke-sci.sh
#       CONTAINER_CMD=docker|podman  (默认 docker, 构建沙箱可用 podman)
# 验证:
#   1. SageMath 仍可用 (venv 隔离未破坏系统环境)
#   2. 全部科学包可导入
#   3. Jupyter 内核注册 (python3(Science) + sagemath + sci-env)
#   4. 科学内核端到端执行
#   5. JupyterLab HTTP 200
#   6. [v3.0] Launcher 内核列表含 sagemath 且官方图标 URL 返回 200
#      (回归 v2.0 缺失 sagemath 图标问题)
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${IMAGE:?需要设置 IMAGE 环境变量}"
CONTAINER_CMD="${CONTAINER_CMD:-docker}"

echo "=== [1/6] SageMath 兼容性 (venv 隔离保护) ==="
"$CONTAINER_CMD" run --rm "$IMAGE" sage --version
"$CONTAINER_CMD" run --rm "$IMAGE" sage -c 'assert is_prime(99991); print("[OK] sage 数学计算正常")'

echo "=== [2/6] 科学包导入 ==="
"$CONTAINER_CMD" run --rm "$IMAGE" /opt/sci-env/bin/python - <<'PY'
import sys
errors = []
tests = [
    ('numpy', lambda: __import__('numpy')),
    ('scipy', lambda: __import__('scipy')),
    ('pandas', lambda: __import__('pandas')),
    ('matplotlib', lambda: __import__('matplotlib')),
    ('sklearn', lambda: __import__('sklearn')),
    ('scikit_image', lambda: __import__('skimage')),
    ('sympy', lambda: __import__('sympy')),
    ('ase', lambda: __import__('ase')),
    ('pymatgen', lambda: __import__('pymatgen')),
    ('crystal_toolkit', lambda: __import__('crystal_toolkit')),
    ('pymatviz', lambda: __import__('pymatviz')),
    ('hyperspy', lambda: __import__('hyperspy')),
    ('rsciio', lambda: __import__('rsciio')),
    ('rsciio.edax', lambda: __import__('rsciio.edax')),
    ('xraylarch(larch)', lambda: __import__('larch')),
    ('pywbem', lambda: __import__('pywbem')),
    ('torch', lambda: __import__('torch')),
    ('PyXplore', lambda: __import__('PyXplore')),
    ('h5py', lambda: __import__('h5py')),
    ('dask', lambda: __import__('dask')),
    ('numba', lambda: __import__('numba')),
    ('pybaselines', lambda: __import__('pybaselines')),
]
for name, test in tests:
    try:
        test()
        print(f"  [OK] {name}")
    except Exception as e:
        print(f"  [FAIL] {name}: {e}")
        errors.append(name)
if errors:
    print(f"ERROR: {len(errors)} packages failed: {errors}")
    sys.exit(1)
print(f"All {len(tests)} packages verified successfully!")
PY

echo "=== [3/6] Jupyter 内核注册 (全局 kernelspec) ==="
"$CONTAINER_CMD" run --rm "$IMAGE" jupyter kernelspec list
"$CONTAINER_CMD" run --rm "$IMAGE" jupyter kernelspec list | grep -q "sagemath" \
  && echo "[OK] sagemath 内核"
"$CONTAINER_CMD" run --rm "$IMAGE" jupyter kernelspec list | grep -q "python3" \
  && echo "[OK] python3 (Science) 内核"
"$CONTAINER_CMD" run --rm "$IMAGE" jupyter kernelspec list | grep -q "sci-env" \
  && echo "[OK] sci-env (具名) 内核"

echo "=== [4/6] 科学内核端到端执行 ==="
# 注意: 容器默认 PATH 首位为 /usr/local/bin, 但其下无 python3 (系统 python3 在 /usr/bin);
#       故显式使用 /usr/bin/python3 (Debian 系统 python, 已装 nbconvert)
"$CONTAINER_CMD" run --rm --user 1000 -v "$ROOT/tests:/tests:ro" "$IMAGE" \
  bash -c 'cp /tests/sci-kernel-test.ipynb /tmp/ && cd /tmp && /usr/bin/python3 -m nbconvert --to notebook --execute --ExecutePreprocessor.kernel_name=python3 --ExecutePreprocessor.timeout=180 --inplace sci-kernel-test.ipynb >/dev/null 2>&1 && /opt/sci-env/bin/python -c "import json; nb=json.load(open(\"/tmp/sci-kernel-test.ipynb\")); texts=[]; [texts.extend(o.get(\"text\",\"\") if isinstance(o.get(\"text\",\"\"),list) else [o.get(\"text\",\"\")]) for c in nb[\"cells\"] for o in c.get(\"outputs\",[]) if o.get(\"output_type\")==\"stream\"]; assert any(\"ALL_SCI_PACKAGES_OK\" in t for t in texts), texts; print(\"[OK] 科学内核执行: numpy+scipy+torch 全部通过\")"'

echo "=== [5/6] JupyterLab 服务检查 ==="
CID="sage-sci-smoke-$$"
"$CONTAINER_CMD" run -d --name "$CID" -p 18889:8888 -e JUPYTER_TOKEN=smoketest "$IMAGE"
trap '"$CONTAINER_CMD" rm -f "$CID" >/dev/null 2>&1 || true' EXIT
ready=0
for _ in $(seq 1 60); do
  if curl -sf -o /dev/null "http://127.0.0.1:18889/lab"; then ready=1; break; fi
  sleep 2
done
if [ "$ready" != "1" ]; then
  echo "[FAIL] JupyterLab 未在预期时间内就绪"
  "$CONTAINER_CMD" logs "$CID" 2>&1 | tail -30
  exit 1
fi
curl -sf -o /dev/null "http://127.0.0.1:18889/lab?token=smoketest" \
  && echo "[OK] JupyterLab 返回 HTTP 200"

echo "=== [6/6] v3.0 Launcher 内核与图标校验 (回归 v2.0 缺图标) ==="
# /api/kernelspecs 是 Launcher Notebook/Console 栏的数据来源
for ks in sagemath python3 sci-env; do
  curl -sf "http://127.0.0.1:18889/api/kernelspecs?token=smoketest" \
    | grep -q "\"$ks\"" && echo "[OK] kernelspecs 包含 $ks" \
    || { echo "[FAIL] kernelspecs 缺失 $ks"; exit 1; }
done
# 图标 URL 必须返回 200 (缺失图标时 JupyterLab 无法加载 -> Launcher 无专属图标)
for u in "sagemath/logo-64x64.png" "sagemath/logo-32x32.png" \
         "python3/logo-64x64.png" "sci-env/logo-64x64.png"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    "http://127.0.0.1:18889/kernelspecs/$u?token=smoketest")
  [ "$code" = "200" ] && echo "[OK] 图标 $u -> 200" \
    || { echo "[FAIL] 图标 $u -> $code"; exit 1; }
done

echo "=== 科学环境测试全部通过 ==="
