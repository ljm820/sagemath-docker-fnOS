#!/usr/bin/env bash
# =============================================================================
# 使用 NVIDIA SkillSpector 对项目代码与操作进行安全扫描
#
# 参考: https://github.com/nvidia/skillspector
# 说明: 静态扫描在本地完成(--no-llm), 不会将代码上传到第三方。
#       可选 LLM 语义分析请按需配置 SKILLSPECTOR_PROVIDER 等环境变量。
#
# 用法: ./scripts/security-scan.sh
# 输出: docs/security/skillspector-report.md / .json
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# 1) 确保 uv 可用
if ! command -v uv >/dev/null 2>&1; then
  echo ">>> 安装 uv ..."
  python3 -m pip install --break-system-packages -q uv \
    || python3 -m pip install -q uv
  export PATH="$HOME/.local/bin:$PATH"
fi
export PATH="$HOME/.local/bin:$PATH"

# 2) 确保 skillspector 可用 (要求 Python 3.12+, 由 uv 自动管理)
if ! command -v skillspector >/dev/null 2>&1; then
  echo ">>> 安装 NVIDIA SkillSpector ..."
  uv tool install --python 3.12 'git+https://github.com/NVIDIA/skillspector.git'
fi

# 3) 执行静态安全扫描 (使用基线文件抑制已审阅的误报)
# 说明: 加大 OSV.dev 请求超时, 避免网络抖动被误报为 "SC4 fallback" 问题
echo ">>> 运行 skillspector scan (static, --no-llm, 基线: .skillspector-baseline.yaml) ..."
export SKILLSPECTOR_OSV_TIMEOUT="${SKILLSPECTOR_OSV_TIMEOUT:-60}"
mkdir -p docs/security
if [ -f "$ROOT/.skillspector-baseline.yaml" ]; then
  BASELINE=(--baseline "$ROOT/.skillspector-baseline.yaml")
else
  BASELINE=()
fi
skillspector scan "$ROOT" --no-llm "${BASELINE[@]}" --format markdown --output docs/security/skillspector-report.md
skillspector scan "$ROOT" --no-llm "${BASELINE[@]}" --format json    --output docs/security/skillspector-report.json

echo ">>> 报告已生成:"
echo "    docs/security/skillspector-report.md"
echo "    docs/security/skillspector-report.json"
echo ">>> 基线误报抑制清单: .skillspector-baseline.yaml"
echo ">>> 新增风险评分 > 50 时 exit code 为 1, 请结合 docs/SECURITY.md 处置"
