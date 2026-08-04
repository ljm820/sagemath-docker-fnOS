# 测试运行说明

## 测试类型与命令

| 类型     | 命令                                        | 覆盖内容                                |
|----------|---------------------------------------------|-----------------------------------------|
| 冒烟测试 | `./scripts/test.sh debian12`               | 版本、数学计算、.sage 脚本、内核执行、Jupyter HTTP 200 |
| 全量测试 | `make test` / `./scripts/test.sh all`       | 三个镜像依次冒烟测试                    |
| 脚本断言 | `docker run --rm <镜像> sage --python tests/test-suite.py` | sage.all 导入、基础数学、jupyterlab 版本 |

## 冒烟测试明细 (tests/smoke.sh)

1. **SageMath 版本**：`sage --version`
2. **数学计算断言**：
   - `2^100 == 1267650600228229401496703205376`
   - `factor(1000) == 2^3 * 5^3`（注意：`factor()` 返回 `Factorization` 对象，须用 `str()` 与字符串比较）
   - `is_prime(99991)` 为真、`is_prime(99992)` 为假
   - `e^pi > pi^e`
3. **独立脚本**：`sage math-check.sage`，覆盖符号积分与有限域椭圆曲线
4. **内核注册与执行**：
   - `jupyter kernelspec list` 含 `sagemath`
   - `python3 -m nbconvert --execute --ExecutePreprocessor.kernel_name=sagemath` 端到端执行 `kernel-test.ipynb`，校验 `2^100` 输出
5. **JupyterLab 服务**：后台起容器，轮询 `http://127.0.0.1:18888/lab` 直到返回 200

## 手动验证 Jupyter + Sage 内核

```bash
docker exec -it sagemath-debian12 sage
# 交互式 Sage 命令行验证:
#   sage: factor(2^127-1)
```

```bash
# 查看内核是否注册 (期望输出同时含 python3 与 sagemath)
docker exec sagemath-debian12 jupyter kernelspec list
# 期望输出:
#   python3     /home/sage/.local/share/jupyter/kernels/python3
#   sagemath    /home/sage/.local/share/jupyter/kernels/sagemath
```

## 已验证结果 (Debian 12 版, SageMath 9.5)

2026-08-04 在 podman 4.3.1 真机验证通过：

- `sage --version` → `SageMath version 9.5, Release Date: 2022-01-30`
- 数学断言：`2^100`、`factor(1000)`、`is_prime`、`e^pi > pi^e` 全部通过
- 独立脚本 `math-check.sage` 全部通过（含符号积分、椭圆曲线 `GF(97)` 阶 97）
- Jupyter 内核：`python3` + `sagemath` 均已注册
- 端到端执行：sagemath 内核运行 `2^100` → `1267650600228229401496703205376`
- JupyterLab：`/lab?token=` 返回 HTTP 200

> 提示：Debian 版 `sage.repl.ipython_kernel` 没有 `install` 子命令，
> 镜像内的 sagemath 内核采用静态 kernelspec
> (`images/debian12/kernelspec/sagemath/kernel.json`) 注册，勿用
> `sage --python -m sage.repl.ipython_kernel install` 替代。

## 手动验证 JupyterLab 登录

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  "http://127.0.0.1:8888/lab?token=<JUPYTER_TOKEN>"
# 200 = 正常
```

## 回归测试建议

每次修改 Dockerfile 后执行：

```bash
./scripts/build.sh debian12 && ./scripts/test.sh debian12
```

若 Dockerfile 层缓存导致测试不准确，可 `--no-cache` 强制重建：

```bash
docker build --no-cache -t ljm820/sagemath-fnos:debian12-sage9.5 images/debian12
```
