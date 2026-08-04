# SageMath 冒烟测试脚本
# 用法: sage math-check.sage
# 覆盖: 版本、整数运算、质因数分解、质数判定、符号积分、有限域椭圆曲线

print("SageMath 版本:", version())

assert 2^100 == 1267650600228229401496703205376
print("[OK] 2^100")

assert str(factor(ZZ(1000))) == "2^3 * 5^3"
print("[OK] factor(1000) =", factor(ZZ(1000)))

assert is_prime(99991)
assert not is_prime(99992)
print("[OK] is_prime(99991) = True")

r = integrate(x * sin(x), x)
assert str(r) == "-x*cos(x) + sin(x)"
print("[OK] integrate(x*sin(x), x) =", r)

E = EllipticCurve(GF(97), [1, 1])
assert E.order() > 0
print("[OK] EllipticCurve(GF(97),[1,1]) 阶 =", E.order())

print("[ALL PASSED] SageMath 冒烟测试全部通过")
