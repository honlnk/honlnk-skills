#!/usr/bin/env bash
# honlnk-skills 安装脚本：把 skills/ 下每个技能以 symlink 接入用户级技能目录。
#
# 背景：ZCode 等本地 Agent 对用户级技能根（如 ~/.agents/skills）只扫描一层，
# 但会跟随 symlink——因此仓库内 skills/<name>/ 结构可原样接入，无需平铺。
# 幂等：重复执行安全。目标位置已有非本仓库内容时默认拒绝，--force 才备份替换。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${REPO_ROOT}/skills"
TARGET_ROOT="${HONLNK_SKILLS_TARGET_ROOT:-${HOME}/.agents/skills}"
FORCE=0

usage() {
  cat <<EOF
用法: ./install.sh [--force]
  把 ${SKILLS_DIR} 下的每个技能目录 symlink 到 ${TARGET_ROOT}/<技能名>

选项:
  --force     目标位置已有非本仓库内容时，先备份为 <名>.bak-<时间戳> 再替换
  -h, --help  显示本帮助

环境变量:
  HONLNK_SKILLS_TARGET_ROOT  覆盖目标技能根目录（默认 ~/.agents/skills）
EOF
}

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: ${arg}" >&2; usage >&2; exit 2 ;;
  esac
done

if [ ! -d "${SKILLS_DIR}" ]; then
  echo "错误: 未找到 ${SKILLS_DIR}" >&2
  exit 1
fi

mkdir -p "${TARGET_ROOT}"

installed=0
skipped=0
failed=0

for skill_path in "${SKILLS_DIR}"/*/; do
  [ -d "${skill_path}" ] || continue
  skill_name="$(basename "${skill_path}")"
  skill_src="${skill_path%/}"
  target="${TARGET_ROOT}/${skill_name}"

  # 已是指向本仓库的 symlink：幂等跳过
  if [ -L "${target}" ] && [ "$(readlink "${target}")" = "${skill_src}" ]; then
    echo "[OK]    ${skill_name} 已是最新（symlink 无变化）"
    installed=$((installed + 1))
    continue
  fi

  # 目标位置被占用（目录/文件/指向别处的链接/坏链接）
  if [ -e "${target}" ] || [ -L "${target}" ]; then
    if [ "${FORCE}" -ne 1 ]; then
      echo "[SKIP]  ${skill_name}: ${target} 已存在且不是指向本仓库的 symlink（用 --force 备份替换）" >&2
      skipped=$((skipped + 1))
      continue
    fi
    backup="${target}.bak-$(date +%Y%m%d-%H%M%S)"
    mv "${target}" "${backup}"
    echo "[BACKUP] ${skill_name}: 原有内容已备份到 ${backup}"
    if ! ln -s "${skill_src}" "${target}"; then
      mv "${backup}" "${target}"
      echo "[FAIL]  ${skill_name}: 建链失败，已把备份还原回 ${target}" >&2
      failed=$((failed + 1))
      continue
    fi
    echo "[OK]    ${skill_name} 已安装 -> ${target}（原内容备份于 ${backup}）"
    installed=$((installed + 1))
    continue
  fi

  if ! ln -s "${skill_src}" "${target}"; then
    echo "[FAIL]  ${skill_name}: 建链失败" >&2
    failed=$((failed + 1))
    continue
  fi
  echo "[OK]    ${skill_name} 已安装 -> ${target}"
  installed=$((installed + 1))
done

# skills/ 为空（只有 .gitkeep 等）时上面循环体一次都不进，属正常情况
if [ "${installed}" -eq 0 ] && [ "${skipped}" -eq 0 ] && [ "${failed}" -eq 0 ]; then
  echo "skills/ 下暂无可安装的技能目录，无事可做。"
fi

[ "${skipped}" -eq 0 ] || echo "提醒: ${skipped} 个技能因冲突跳过" >&2
[ "${failed}" -eq 0 ] || echo "提醒: ${failed} 个技能安装失败" >&2
[ "${failed}" -eq 0 ]
