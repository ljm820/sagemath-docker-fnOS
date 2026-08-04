#!/usr/bin/env bash
# =============================================================================
# SageMath 镜像冒烟测试
# 用法: IMAGE=ljm820/sagemath-fnos:debian12-sage9.5 tests/smoke.sh
# 通过 docker run 依次验证:
#   1. sage 可执行与版本
#   2. 数学计算 (幂、质因数分解、质数判定)
#   3. 独立 .sage 脚本执行
#   4. Jupyter 内核注册 + 端到端执行
#   5. JupyterLab 服务 HTTP 200
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${IMAGE:?需要设置 IMAGE 环境变量, 例如 IMAGE=ljm820/sagemath-fnos:debian12-sage9.5}"

echo "=== [1/5] SageMath 版本 ==="
docker run --rm "$IMAGE" sage --version

echo "=== [2/5] 数学计算断言 ==="
docker run --rm "$IMAGE" sage -c 'assert 2^100 == 1267650600228229401496703205376; print("[OK] 2^100")'
docker run --rm "$IMAGE" sage -c 'assert str(factor(ZZ(1000))) == "2^3 * 5^3"; print("[OK] factor(1000)")'
docker run --rm "$IMAGE" sage -c 'assert is_prime(99991); assert not is_prime(99992); print("[OK] is_prime")'
docker run --rm "$IMAGE" sage -c 'print("[OK] e^pi =", float(e^pi), " > pi^e =", float(pi^e), "->", bool(e^pi > pi^e))'

echo "=== [3/5] 独立 sage 脚本 ==="
# sage-preparse 需要在脚本所在目录写入临时文件, 故先拷贝到容器内可写路径执行
docker run --rm -v "$ROOT/tests:/tests:ro" "$IMAGE" \
  bash -c 'cp /tests/math-check.sage /tmp/ && sage /tmp/math-check.sage'

echo "=== [4/5] Jupyter 内核注册与端到端执行 ==="
docker run --rm "$IMAGE" jupyter kernelspec list | grep -q sagemath \
  && echo "[OK] sagemath 内核已注册"
docker run --rm -v "$ROOT/tests:/tests:ro" "$IMAGE" \
  bash -c 'cp /tests/kernel-test.ipynb /tmp/ && python3 -m nbconvert --to notebook --execute --ExecutePreprocessor.kernel_name=sagemath --inplace /tmp/kernel-test.ipynb >/dev/null 2>&1 && python3 -c "import json; nb=json.load(open(\"/tmp/kernel-test.ipynb\")); o=nb[\"cells\"][0][\"outputs\"][0][\"data\"][\"text/plain\"]; assert o==[\"1267650600228229401496703205376\"], o; print(\"[OK] sage 内核执行 2^100 =\", o[0])"'

echo "=== [5/5] JupyterLab 服务检查 ==="
CID="sage-smoke-$$"
docker run -d --name "$CID" -p 18888:8888 -e JUPYTER_TOKEN=smoketest "$IMAGE"
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT

ready=0
for _ in $(seq 1 40); do
  if curl -sf -o /dev/null "http://127.0.0.1:18888/lab"; then ready=1; break; fi
  sleep 2
done
if [ "$ready" != "1" ]; then
  echo "[FAIL] JupyterLab 未在预期时间内就绪"
  docker logs "$CID" 2>&1 | tail -30
  exit 1
fi
curl -sf -o /dev/null "http://127.0.0.1:18888/lab?token=smoketest" \
  && echo "[OK] JupyterLab 返回 HTTP 200"

echo "=== 全部测试通过 ==="
