#!/usr/bin/env python3
# SageMath 基础断言测试 (可在容器内用 `sage --python tests/test-suite.py` 运行)
import sys

try:
    from sage.all import *  # noqa: F401,F403
except ImportError as exc:
    print("无法导入 sage.all:", exc)
    sys.exit(1)

assert 2**100 == 1267650600228229401496703205376
assert str(factor(1000)) == "2^3 * 5^3"
assert is_prime(99991)
assert not is_prime(99992)

print("[test-suite] sage.all 导入与基础断言通过")

try:
    import jupyterlab
    print("[test-suite] jupyterlab 版本:", jupyterlab.__version__)
except ImportError:
    print("[test-suite][WARN] jupyterlab 未安装")
