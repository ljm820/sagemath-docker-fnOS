#!/usr/bin/env python3
# =============================================================================
# v3.0: 为 Jupyter 内核生成 Launcher / Select Kernel 图标
#
# JupyterLab 4 自动加载内核目录下 resources/logo-32x32.png 与 logo-64x64.png
# 作为 Launcher 卡片与 Select Kernel 下拉图标, 无需任何插件。
# 配色与《JupyterLab多环境内核注册与使用方案.md》第 11 节一致:
#   深海军蓝 #0C447C + 琥珀 #EF9F27 + 白色, 扁平风材料科学徽章。
#
# 用法:
#   python gen-kernel-icons.py --kernel <kernelspec_dir> [--kernel <dir> ...]
# =============================================================================
import argparse
import os

from PIL import Image, ImageDraw

NAVY = (12, 68, 124, 255)      # #0C447C
AMBER = (239, 159, 39, 255)    # #EF9F27
WHITE = (255, 255, 255, 255)


def draw_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = float(size)
    cx, cy = s * 0.50, s * 0.52
    r = s * 0.15

    # 圆形徽章
    d.ellipse([0, 0, s - 1, s - 1], fill=NAVY)

    # 八面体球棍模型: 上顶点/下顶点 + 赤道方形 4 原子
    top = (cx, cy - r)
    bottom = (cx, cy + r)
    eq = [
        (cx - r, cy), (cx + r, cy),
        (cx, cy + r * 0.95), (cx, cy - r * 0.95),
    ]
    # 键(琥珀)
    for a, b in [(top, eq[0]), (top, eq[1]), (top, eq[2]), (top, eq[3]),
                 (bottom, eq[0]), (bottom, eq[1]), (bottom, eq[2]), (bottom, eq[3]),
                 (eq[0], eq[1]), (eq[2], eq[3])]:
        d.line([a, b], fill=AMBER, width=max(2, int(s // 28)))
    # 原子(白色球)
    for p in [top, bottom] + eq:
        pr = max(2.0, s * 0.032)
        d.ellipse([p[0] - pr, p[1] - pr, p[0] + pr, p[1] + pr], fill=WHITE)
    # 上顶点用琥珀强调
    d.ellipse([top[0] - r * 0.14, top[1] - r * 0.14,
               top[0] + r * 0.14, top[1] + r * 0.14], fill=AMBER)

    # XRD 衍射棒图 (右上): 5 根琥珀竖线
    x0, y_base = s * 0.70, s * 0.30
    heights = [0.16, 0.30, 0.22, 0.38, 0.13]
    for i, h in enumerate(heights):
        x = x0 + i * s * 0.055
        top_y = y_base - h * s
        d.line([(x, y_base), (x, top_y)], fill=AMBER, width=max(1, int(s // 48)))

    # XAS 吸收谱 (右下): 水平基线 -> edge jump -> XANES 振荡 -> EXAFS 阻尼
    x0, y0 = s * 0.60, s * 0.86
    d.line([(x0, y0), (x0 + s * 0.30, y0)], fill=WHITE, width=max(1, int(s // 56)))
    pts = [(x0, y0)]
    step = s * 0.008
    # edge jump
    pts.append((x0 + s * 0.05, y0))
    pts.append((x0 + s * 0.06, y0 - s * 0.14))
    # XANES 振荡 + EXAFS 阻尼衰减
    for i in range(60):
        x = x0 + s * 0.06 + i * step
        amp = s * 0.14 * (0.72 ** (i / 18.0))
        y = y0 - amp * abs((i + 8) % 12 - 6) / 6.0
        pts.append((x, y))
    for i in range(1, len(pts)):
        d.line([pts[i - 1], pts[i]], fill=WHITE, width=max(1, int(s // 56)))

    return img


def main() -> None:
    ap = argparse.ArgumentParser(description="generate jupyter kernel icons")
    ap.add_argument("--kernel", action="append", required=True,
                    help="kernelspec directory (repeatable)")
    args = ap.parse_args()

    for kdir in args.kernel:
        res = os.path.join(kdir, "resources")
        os.makedirs(res, exist_ok=True)
        for px in (32, 64):
            draw_icon(px).save(os.path.join(res, f"logo-{px}x{px}.png"))
        print(f"[OK] icons -> {res}")


if __name__ == "__main__":
    main()
