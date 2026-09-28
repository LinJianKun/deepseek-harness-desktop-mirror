#!/usr/bin/env bash
#
# 把两个 DeepSeek Harness 安装包发布到 GitHub。
#
# 用法：
#   ./release.sh                       # 用默认仓库名
#   REPO_NAME=my-repo ./release.sh     # 自定义仓库名
#
# 幂等：仓库/Release 已存在时会跳过，可安全重复运行。
#
# 注意：本脚本会访问 github.com。在 DSH 沙箱内 github.com 被网络策略拦截，
#       请在能访问 GitHub 的机器上运行（你的个人电脑）。

set -euo pipefail

# ---------- 配置 ----------
REPO_NAME="${REPO_NAME:-deepseek-harness-desktop-mirror}"
TAG="${TAG:-v0.1.7-rc.2}"
TITLE="${TITLE:-DeepSeek Harness Desktop 0.1.7-rc.2 安装包}"
ASSETS_DIR="${ASSETS_DIR:-.}"   # 安装包与本脚本位于同一目录

DMG="deepseek-harness-0.1.7-rc.2-mac-arm64.dmg"
EXE="deepseek-harness-0.1.7-rc.2-win-x64.exe"

DMG_SHA="30909618ec09559448fc5bb28dffd7111c66e30f9b2142165fb9a812896f6607"
EXE_SHA="0cf065dc2fc56456448620230581a9072477f0b2562bbc4e1709cdaedd3ceb86"

# ---------- 前置检查 ----------
echo "==> 检查依赖"
command -v gh >/dev/null || { echo "错误：未找到 gh CLI，请先安装：brew install gh"; exit 1; }
command -v shasum >/dev/null || { echo "错误：未找到 shasum"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "错误：gh 未登录，请运行 gh auth login"; exit 1; }

ACCOUNT="$(gh api user --jq .login)"
echo "    已登录账号：$ACCOUNT"
echo "    目标仓库：$ACCOUNT/$REPO_NAME"

echo "==> 检查安装包是否存在"
for f in "$ASSETS_DIR/$DMG" "$ASSETS_DIR/$EXE"; do
  [ -f "$f" ] || { echo "错误：找不到 $f"; exit 1; }
  echo "    OK  $f  ($(du -h "$f" | cut -f1))"
done

echo "==> 校验 SHA-256（防止上传到错误的文件）"
check_sha() {
  local file="$1" want="$2"
  local got
  got="$(shasum -a 256 "$file" | awk '{print $1}')"
  if [ "$got" != "$want" ]; then
    echo "错误：$file 校验值不匹配"
    echo "  期望 $want"
    echo "  实际 $got"
    exit 1
  fi
  echo "    OK  $(basename "$file")"
}
check_sha "$ASSETS_DIR/$DMG" "$DMG_SHA"
check_sha "$ASSETS_DIR/$EXE" "$EXE_SHA"

# ---------- 建仓库 ----------
echo "==> 创建仓库"
if gh repo view "$ACCOUNT/$REPO_NAME" >/dev/null 2>&1; then
  echo "    仓库已存在，跳过"
else
  gh repo create "$REPO_NAME" \
    --public \
    --description "DeepSeek Harness Desktop 安装包非官方镜像（win-x64 / mac-arm64）| Unofficial installer mirror. Prefer official downloads." \
    --homepage "https://github.com/deepseek-ai/deepseek-harness"
  echo "    已创建"
fi

# ---------- 同步仓库文件 ----------
# 自动收录版本化文档与同步工具，避免每次新增文件都要改本脚本。
# 排除：安装包二进制与本地杂项。
# 注意：.github/workflows/ 下的文件需要 token 具备 workflow scope，
#       否则 GitHub 会以 404 拒绝推送（不是路径错误）。
echo "==> 同步仓库文件"
REPO_FILES=(
  README.md
  LICENSE
  NOTICE
  release.sh
  .gitignore
  .gitattributes
  scripts/sync-upstream.sh
  .github/workflows/sync-upstream.yml
)

WORKFLOW_FAILED=0

for f in "${REPO_FILES[@]}"; do
  [ -f "$f" ] || { echo "    跳过（不存在）$f"; continue; }

  if gh api "repos/$ACCOUNT/$REPO_NAME/contents/$f" >/dev/null 2>&1; then
    SHA_CUR="$(gh api "repos/$ACCOUNT/$REPO_NAME/contents/$f" --jq .sha)"
    if gh api -X PUT "repos/$ACCOUNT/$REPO_NAME/contents/$f" \
        -f message="chore: update $f" \
        -f content="$(base64 < "$f" | tr -d '\n')" \
        -f sha="$SHA_CUR" >/dev/null 2>&1; then
      echo "    已更新 $f"
    else
      echo "    ❌ 更新失败 $f"
      case "$f" in .github/workflows/*) WORKFLOW_FAILED=1 ;; esac
    fi
  else
    if gh api -X PUT "repos/$ACCOUNT/$REPO_NAME/contents/$f" \
        -f message="chore: add $f" \
        -f content="$(base64 < "$f" | tr -d '\n')" >/dev/null 2>&1; then
      echo "    已添加 $f"
    else
      echo "    ❌ 添加失败 $f"
      case "$f" in .github/workflows/*) WORKFLOW_FAILED=1 ;; esac
    fi
  fi
done

if [ "$WORKFLOW_FAILED" = "1" ]; then
  echo "    ⚠️  workflow 文件推送失败。该路径需要 token 具备 workflow scope："
  echo "        gh auth refresh -h github.com -s workflow"
  echo "        也可在 GitHub 网页端手动添加该文件（见 README 说明）"
fi

# ---------- 设置 topics（提升可搜索性） ----------
echo "==> 设置仓库 topics"
gh api -X PUT "repos/$ACCOUNT/$REPO_NAME/topics" \
  -H "Accept: application/vnd.github+json" \
  -f names[]="deepseek" \
  -f names[]="deepseek-harness" \
  -f names[]="dsh" \
  -f names[]="installer" \
  -f names[]="mirror" \
  -f names[]="desktop-app" >/dev/null || echo "    topics 设置失败（非致命，可忽略）"
echo "    已设置"

# ---------- 建 Release 并上传 ----------
echo "==> 创建 Release $TAG"
if gh release view "$TAG" --repo "$ACCOUNT/$REPO_NAME" >/dev/null 2>&1; then
  # 资产若已存在且字节数一致，跳过上传（避免每次同步文档都重传数百 MB）
  SKIP_UPLOAD=1
  for pair in "$DMG:$DMG_SHA" "$EXE:$EXE_SHA"; do
    name="${pair%%:*}"
    local_size="$(wc -c < "$ASSETS_DIR/$name" | tr -d ' ')"
    remote_size="$(gh api "repos/$ACCOUNT/$REPO_NAME/releases/tags/$TAG" \
      --jq ".assets[] | select(.name==\"$name\") | .size" 2>/dev/null | head -1 || true)"
    if [ "$local_size" != "$remote_size" ]; then
      echo "    $name 远端缺失或大小不符，需要上传"
      SKIP_UPLOAD=0
    fi
  done

  if [ "$SKIP_UPLOAD" = "1" ]; then
    echo "    资产已存在且大小一致，跳过上传"
  else
    echo "    上传/覆盖资产"
    gh release upload "$TAG" \
      "$ASSETS_DIR/$DMG" "$ASSETS_DIR/$EXE" \
      --repo "$ACCOUNT/$REPO_NAME" --clobber
  fi
else
  gh release create "$TAG" \
    "$ASSETS_DIR/$DMG" "$ASSETS_DIR/$EXE" \
    --repo "$ACCOUNT/$REPO_NAME" \
    --title "$TITLE" \
    --notes "DeepSeek Harness Desktop \`0.1.7-rc.2\` 官方安装包副本（未修改）。

| 文件 | 平台 | SHA-256 |
| --- | --- | --- |
| \`$DMG\` | macOS 13+ / Apple Silicon | \`$DMG_SHA\` |
| \`$EXE\` | Windows 10/11 x64 | \`$EXE_SHA\` |

**非官方镜像。** 上游项目：https://github.com/deepseek-ai/deepseek-harness
许可证：MIT（见仓库 LICENSE 文件）。"
fi

echo
echo "==> 完成"
echo "    仓库：https://github.com/$ACCOUNT/$REPO_NAME"
echo "    Release：https://github.com/$ACCOUNT/$REPO_NAME/releases/tag/$TAG"
echo
echo "请在能访问 GitHub 的浏览器里验证以下两件事："
echo "  1. 匿名（退出登录 / 无痕窗口）打开上面的 Release 页，资产能否直接下载；"
echo "  2. 匿名打开 https://github.com/search?q=$REPO_NAME&type=repositories 能否搜到。"
