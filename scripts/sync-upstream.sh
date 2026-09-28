#!/usr/bin/env bash
#
# 自动同步 DeepSeek Harness 官方安装包到本仓库。
#
# 原理：
#   1. 读上游 GitHub 仓库的 release tag（形如 dsh-v0.2.0-rc.1）
#   2. 从 tag 解析出版本号（0.2.0-rc.1）
#   3. 按官方下载站的固定 URL 模式探测该版本的两个安装包
#   4. 下载、计算 SHA-256、发布为本仓库的 Release
#   5. 更新 README 的版本表格与校验值
#
# 用法：
#   ./sync-upstream.sh                # 同步上游最新版本
#   ./sync-upstream.sh 0.2.0-rc.1     # 同步指定版本
#   ./sync-upstream.sh --all          # 回填所有缺失的历史版本
#   ./sync-upstream.sh 0.1.7-rc.2 --force   # 强制重新下载并重算校验值
#   ./sync-upstream.sh --dry-run      # 只探测不下载不上传
#
# 环境变量（GitHub Actions 中由 workflow 注入）：
#   GH_TOKEN   具有 repo 权限的 token
#   REPO       目标仓库，默认 LinJianKun/deepseek-harness-desktop-mirror
#   README     要更新的 README 路径，默认 ./README.md

set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-deepseek-ai/deepseek-harness}"
REPO="${REPO:-LinJianKun/deepseek-harness-desktop-mirror}"
README="${README:-./README.md}"
DOWNLOAD_BASE="${DOWNLOAD_BASE:-https://download.deepseek.com/dsh-desk/bin}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

DRY_RUN=0
FORCE=0
MODE="latest"
TARGET_VERSION=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    --all)     MODE="all" ;;
    -*)        echo "未知参数: $arg" >&2; exit 2 ;;
    *)         MODE="version"; TARGET_VERSION="$arg" ;;
  esac
done

log() { printf '%s\n' "$*" >&2; }

# ---------- 依赖检查 ----------
need() { command -v "$1" >/dev/null || { log "缺少依赖: $1"; exit 1; }; }
need gh; need curl; need shasum; need python3

# ---------- 读取上游发布列表 ----------
log "==> 读取上游发布列表：$UPSTREAM_REPO"
gh api "repos/$UPSTREAM_REPO/releases?per_page=100" > "$WORK/upstream.json"

# 输出：<version>\t<tag>\t<发布日期>，已按上游顺序（新→旧）
python3 - "$WORK/upstream.json" > "$WORK/upstream.tsv" <<'PY'
import json, sys, re
data = json.load(open(sys.argv[1]))
for r in data:
    if r.get("draft"):
        continue
    tag = r.get("tag_name", "")
    if not tag:
        continue
    # dsh-v0.2.0-rc.1 -> 0.2.0-rc.1
    m = re.match(r"^dsh-v(.+)$", tag)
    version = m.group(1) if m else None
    if not version:
        continue
    date = (r.get("published_at") or r.get("created_at") or "")[:10]
    print(f"{version}|{tag}|{date}")
PY

if [ ! -s "$WORK/upstream.tsv" ]; then
  log "上游没有可解析的 dsh-v* 发布，退出。"
  exit 0
fi
log "    上游共 $(wc -l < "$WORK/upstream.tsv" | tr -d ' ') 个版本"

# ---------- 确定要同步的版本列表 ----------
case "$MODE" in
  version)
    if ! grep -q "^${TARGET_VERSION}|" "$WORK/upstream.tsv"; then
      log "错误：上游找不到版本 $TARGET_VERSION"
      exit 1
    fi
    grep "^${TARGET_VERSION}|" "$WORK/upstream.tsv" > "$WORK/todo.tsv"
    ;;
  latest)
    head -1 "$WORK/upstream.tsv" > "$WORK/todo.tsv"
    ;;
  all)
    cp "$WORK/upstream.tsv" "$WORK/todo.tsv"
    ;;
esac

# ---------- 本仓库已有的 release ----------
log "==> 读取本仓库已有 release"
gh release list --repo "$REPO" --limit 100 --json tagName --jq '.[].tagName' \
  > "$WORK/have.txt" 2>/dev/null || : > "$WORK/have.txt"

has_release() { grep -qxF "v$1" "$WORK/have.txt"; }

asset_exists() {  # $1=tag  $2=文件名
  gh release view "$1" --repo "$REPO" --json assets \
    --jq '.assets[].name' 2>/dev/null | grep -qxF "$2"
}

# ---------- 逐版本处理 ----------
NEW_ENTRIES="$WORK/new_entries.tsv"   # version|date|dmg_sha|exe_sha|dmg_size|exe_size
: > "$NEW_ENTRIES"

# 记录本次实际同步的版本，供工作流生成提交信息。
# 注意不能放在 $WORK 下——退出时会被 trap 清理，工作流就读不到了。
SYNCED_VERSIONS="${SYNCED_VERSIONS:-./synced-versions.txt}"
: > "$SYNCED_VERSIONS"

SYNCED=0

while IFS='|' read -r version tag date; do
  [ -n "$version" ] || continue
  log ""
  log "=== 版本 $version (tag $tag, 上游发布 $date) ==="

  DMG="deepseek-harness-${version}-mac-arm64.dmg"
  EXE="deepseek-harness-${version}-win-x64.exe"
  DMG_URL="$DOWNLOAD_BASE/mac-arm64/$DMG"
  EXE_URL="$DOWNLOAD_BASE/win-x64/$EXE"
  MTAG="v${version}"

  NEED_DOWNLOAD=0
  if [ "$FORCE" = "1" ]; then
    log "    --force：重新下载并重算校验值"
    NEED_DOWNLOAD=1
  elif has_release "$version" && asset_exists "$MTAG" "$DMG" && asset_exists "$MTAG" "$EXE"; then
    log "    Release 与资产均已存在"
    if [ "$MODE" = "all" ]; then
      log "    跳过（回填模式下不重复下载）"
      continue
    fi
    # 最新版本模式：仍需把校验值补进 README
  else
    NEED_DOWNLOAD=1
  fi

  # 探测官方是否已为该版本提供二进制
  dmg_code="$(curl -sI --max-time 60 -o /dev/null -w '%{http_code}' "$DMG_URL" || echo 000)"
  exe_code="$(curl -sI --max-time 60 -o /dev/null -w '%{http_code}' "$EXE_URL" || echo 000)"
  log "    探测: mac-arm64=$dmg_code  win-x64=$exe_code"

  if [ "$dmg_code" != "200" ] || [ "$exe_code" != "200" ]; then
    log "    官方尚未提供该版本的完整二进制，跳过（这是正常情况：打了 tag 但二进制未上传）"
    continue
  fi

  if [ "$DRY_RUN" = "1" ]; then
    log "    [dry-run] 跳过下载与上传"
    continue
  fi

  # ---- 下载并校验 ----
  if [ "$NEED_DOWNLOAD" = "1" ]; then
    for pair in "mac-arm64|$DMG|$DMG_URL" "win-x64|$EXE|$EXE_URL"; do
      arch="${pair%%|*}"; rest="${pair#*|}"; name="${rest%%|*}"; url="${rest#*|}"
      log "    下载 $name"
      curl -fL --retry 3 --retry-delay 5 --max-time 1800 -o "$WORK/$name" "$url" \
        || { log "    下载失败，跳过该版本"; NEED_DOWNLOAD=0; break; }
    done

    if [ -f "$WORK/$DMG" ] && [ -f "$WORK/$EXE" ]; then
      # 上传前先确认本地源文件哈希（若有）
      log "    计算 SHA-256"
      DMG_SHA="$(shasum -a 256 "$WORK/$DMG" | awk '{print $1}')"
      EXE_SHA="$(shasum -a 256 "$WORK/$EXE" | awk '{print $1}')"
      DMG_SIZE="$(wc -c < "$WORK/$DMG" | tr -d ' ')"
      EXE_SIZE="$(wc -c < "$WORK/$EXE" | tr -d ' ')"

      # 建 release（幂等）
      if has_release "$version"; then
        log "    Release 已存在，覆盖资产"
        gh release upload "$MTAG" "$WORK/$DMG" "$WORK/$EXE" --repo "$REPO" --clobber
      else
        log "    创建 Release $MTAG"
        gh release create "$MTAG" "$WORK/$DMG" "$WORK/$EXE" \
          --repo "$REPO" \
          --title "DeepSeek Harness Desktop $version 安装包" \
          --notes "$(cat <<EOF
DeepSeek Harness Desktop \`$version\` 官方安装包副本（未经修改）。

| 文件 | 平台 | 大小 | SHA-256 |
| --- | --- | --- | --- |
| \`$DMG\` | macOS 13+ / Apple Silicon | $DMG_SIZE B | \`$DMG_SHA\` |
| \`$EXE\` | Windows 10/11 x64 | $EXE_SIZE B | \`$EXE_SHA\` |

**非官方镜像。** 官方来源：https://download.deepseek.com/dsh-desk/bin/
上游项目：https://github.com/$UPSTREAM_REPO
许可证：MIT（见仓库 LICENSE 文件）。
EOF
)"
      fi
      rm -f "$WORK/$DMG" "$WORK/$EXE"
    else
      log "    下载不完整，跳过该版本"
      continue
    fi
  fi

  # ---- 记录 README 条目 ----
  if [ -z "${DMG_SHA:-}" ]; then
    # 已有 release 但未下载：从远端资产取回大小，校验值沿用 README 已有记录
    log "    从远端读取资产大小"
    DMG_SIZE="$(gh api "repos/$REPO/releases/tags/$MTAG" --jq ".assets[] | select(.name==\"$DMG\") | .size" 2>/dev/null || echo 0)"
    EXE_SIZE="$(gh api "repos/$REPO/releases/tags/$MTAG" --jq ".assets[] | select(.name==\"$EXE\") | .size" 2>/dev/null || echo 0)"
    DMG_SHA="$(grep -oE '^[0-9a-f]{64}  '"$DMG"'$' "$README" 2>/dev/null | awk '{print $1}' | head -1 || true)"
    EXE_SHA="$(grep -oE '^[0-9a-f]{64}  '"$EXE"'$' "$README" 2>/dev/null | awk '{print $1}' | head -1 || true)"
    if [ -z "$DMG_SHA" ] || [ -z "$EXE_SHA" ]; then
      log "    无法确定校验值（README 中无记录且本次未下载），跳过 README 更新"
      continue
    fi
  fi

  printf '%s|%s|%s|%s|%s|%s\n' \
    "$version" "$date" "$DMG_SHA" "$EXE_SHA" "$DMG_SIZE" "$EXE_SIZE" >> "$NEW_ENTRIES"
  echo "$version" >> "$SYNCED_VERSIONS"
  SYNCED=$((SYNCED + 1))
  DMG_SHA=""; EXE_SHA=""
done < "$WORK/todo.tsv"

# ---------- 更新 README ----------
if [ ! -s "$NEW_ENTRIES" ]; then
  log ""
  log "没有需要更新 README 的版本。"
  exit 0
fi

log ""
log "==> 更新 README（$SYNCED 个版本）"

python3 - "$README" "$NEW_ENTRIES" "$REPO" <<'PY'
import sys, re, os

readme_path, entries_path, repo = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(readme_path, encoding="utf-8").read()

def parse(text):
    """从 README 中解析出已有条目（版本 -> dict）。

    需要同时恢复两类信息：
      - 校验值：来自代码块中的 "<sha>  <文件名>" 行
      - 发布日期与大小：来自详情块的 "发布日期：" 与下载表格
    这样才能在"仅补记校验值、不重新下载"的情况下不丢失元数据。
    """
    existing = {}
    for m in re.finditer(r'^([0-9a-f]{64})  deepseek-harness-([^ ]+)-(mac-arm64\.dmg|win-x64\.exe)$',
                         text, re.M):
        sha, ver, kind = m.group(1), m.group(2), m.group(3)
        e = existing.setdefault(ver, {})
        e["dmg_sha" if kind.startswith("mac") else "exe_sha"] = sha

    # 详情块：<a id="..."></a> ... ### <版本> ... 发布日期：<日期>
    for m in re.finditer(r'^### (\S+)\s*\n+发布日期：(\S+)', text, re.M):
        ver, date = m.group(1), m.group(2)
        if date and date != "—":
            existing.setdefault(ver, {})["date"] = date

    return existing

def version_sort_key(v):
    """版本排序键：数字段优先，预览版低于正式版"""
    base = re.match(r'^(\d+)\.(\d+)\.(\d+)', v)
    parts = tuple(int(x) for x in base.groups()) if base else (0, 0, 0)
    is_pre = 1 if re.search(r'-(alpha|beta|rc)', v) else 0
    return (parts, is_pre, v)

# 已有条目
existing = parse(text)

# 新条目
new = {}
for line in open(entries_path, encoding="utf-8"):
    line = line.rstrip("\n")
    if not line:
        continue
    ver, date, dsha, esha, dsize, esize = line.split("|")
    new[ver] = dict(date=date, dmg_sha=dsha, exe_sha=esha,
                    dmg_size=dsize, exe_size=esize)

# 合并
merged = {}
for ver, e in existing.items():
    merged[ver] = dict(e)
for ver, e in new.items():
    merged[ver] = e

def human(n):
    try:
        n = int(n)
    except (TypeError, ValueError):
        return "—"
    return f"{n/1048576:.0f} MB"

# ---- 表格 ----
rows = []
for ver in sorted(merged, key=version_sort_key, reverse=True):
    e = merged[ver]
    date = e.get("date", "—") or "—"
    rows.append(
        f"| `{ver}` | {date} | [SHA-256](#{ver.replace('.', '')}) | "
        f"[Release](https://github.com/{repo}/releases/tag/v{ver}) |"
    )

table = ("| 版本 | 发布日期 | 校验值 | 详情 |\n"
         "| --- | --- | --- | --- |\n" + "\n".join(rows))

# ---- 详情 ----
details = []
for ver in sorted(merged, key=version_sort_key, reverse=True):
    e = merged[ver]
    date = e.get("date", "—") or "—"
    dsha = e.get("dmg_sha", "—")
    esha = e.get("exe_sha", "—")
    dsize = e.get("dmg_size")
    esize = e.get("exe_size")
    lines = [f'<a id="{ver.replace(".", "")}"></a>', "", f"### {ver}", "",
             f"发布日期：{date}", "",
             "```",
             f"SHA-256",
             f"{dsha}  deepseek-harness-{ver}-mac-arm64.dmg",
             f"{esha}  deepseek-harness-{ver}-win-x64.exe",
             "```", "",
             f"| 文件 | 平台 | 大小 | 下载 |",
             f"| --- | --- | --- | --- |",
             f"| `deepseek-harness-{ver}-mac-arm64.dmg` | macOS 13+ Apple Silicon | {human(dsize)} | [下载](https://github.com/{repo}/releases/download/v{ver}/deepseek-harness-{ver}-mac-arm64.dmg) |",
             f"| `deepseek-harness-{ver}-win-x64.exe` | Windows 10/11 x64 | {human(esize)} | [下载](https://github.com/{repo}/releases/download/v{ver}/deepseek-harness-{ver}-win-x64.exe) |",
             ""]
    details.append("\n".join(lines))

details_text = "\n".join(details)

def replace_block(text, start, end, body):
    pat = re.compile(re.escape(start) + r'.*?' + re.escape(end), re.S)
    if not pat.search(text):
        raise SystemExit(f"README 中找不到标记 {start}")
    return pat.sub(lambda m: start + "\n" + body.rstrip() + "\n" + end, text, count=1)

text = replace_block(text, "<!-- VERSION_TABLE_START -->", "<!-- VERSION_TABLE_END -->", table)
text = replace_block(text, "<!-- VERSION_DETAILS_START -->", "<!-- VERSION_DETAILS_END -->", details_text)

open(readme_path, "w", encoding="utf-8").write(text)
print(f"README 已更新：{len(merged)} 个版本", file=sys.stderr)
PY

log ""
log "==> 完成，共同步 $SYNCED 个版本"
