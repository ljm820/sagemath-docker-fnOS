#!/usr/bin/env bash
# =============================================================================
# v2.0 科学环境冒烟测试 (XRD / EDS / XAS)
# 用法: IMAGE=localhost/ljm820/sagemath-fnos:debian12-sage9.5 tests/smoke-sci.sh
# 验证:
#   1. SageMath 仍可用 (venv 隔离未破坏系统环境)
#   2. 全部科学包可导入
#   3. Jupyter 内核注册 (python3(Science) + sagemath)
#   4. 科学内核端到端执行
#   5. JupyterLab HTTP 200
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${IMAGE:?需要设置 IMAGE 环境变量}"

echo "=== [1/5] SageMath 兼容性 (venv 隔离保护) ==="
docker run --rm "$IMAGE" sage --version
docker run --rm "$IMAGE" sage -c 'assert is_prime(99991); print("[OK] sage 数学计算正常")'

echo "=== [2/5] 科学包导入 ==="
docker run --rm "$IMAGE" /opt/sci-env/bin/python - <<'PY'
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
    ('ovito', lambda: __import__('ovito')),
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

echo "=== [3/5] Jupyter 内核注册 ==="
docker run --rm "$IMAGE" jupyter kernelspec list
docker run --rm "$IMAGE" jupyter kernelspec list | grep -q "sagemath" \
  && echo "[OK] sagemath 内核"
docker run --rm "$IMAGE" jupyter kernelspec list | grep -q "python3" \
  && echo "[OK] python3 (Science) 内核"

echo "=== [4/5] 科学内核端到端执行 ==="
docker run --rm --user 1000 -v "$ROOT/tests:/tests:ro" "$IMAGE" \
  bash -c 'cp /tests/sci-kernel-test.ipynb /tmp/ && cd /tmp && python3 -m nbconvert --to notebook --execute --ExecutePreprocessor.kernel_name=python3 --ExecutePreprocessor.timeout=180 --inplace sci-kernel-test.ipynb >/dev/null 2>&1 && /opt/sci-env/bin/python -c "import json; nb=json.load(open(\"/tmp/sci-kernel-test.ipynb\")); texts=[o.get(\"text\",\"\") for c in nb[\"cells\"] for o in c.get(\"outputs\",[]) if o.get(\"output_type\")==\"stream\"]; assert any(\"ALL_SCI_PACKAGES_OK\" in t for t in texts), texts; print(\"[OK] 科学内核执行: numpy+scipy+torch 全部通过\")"'

echo "=== [5/5] JupyterLab 服务检查 ==="
CID="sage-sci-smoke-$$"
docker run -d --name "$CID" -p 18889:8888 -e JUPYTER_TOKEN=smoketest "$IMAGE"
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT
ready=0
for _ in $(seq 1 40); do
  if curl -sf -o /dev/null "http://127.0.0.1:18889/lab"; then ready=1; break; fi
  sleep 2
done
if [ "$ready" != "1" ]; then
  echo "[FAIL] JupyterLab 未在预期时间内就绪"
  docker logs "$CID" 2>&1 | tail -30
  exit 1
fi
curl -sf -o /dev/null "http://127.0.0.1:18889/lab?token=smoketest" \
  && echo "[OK] JupyterLab 返回 HTTP 200"

echo "=== 科学环境测试全部通过 ==="
