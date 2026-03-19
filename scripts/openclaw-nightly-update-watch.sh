#!/bin/zsh
set -euo pipefail

export PATH="/Users/tongyaojin/Library/pnpm:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
OPENCLAW_BIN="${OPENCLAW_BIN:-/Users/tongyaojin/Library/pnpm/openclaw}"
TARGET_CHANNEL="telegram"
TARGET_CHAT_ID="8449051145"
STATE_DIR="$HOME/.openclaw/update-watch"
LOG_DIR="$STATE_DIR/logs"
TMP_DIR="$STATE_DIR/tmp"
mkdir -p "$LOG_DIR" "$TMP_DIR"

RUN_TS="$(date '+%Y-%m-%d %H:%M:%S %Z')"
LOG_FILE="$LOG_DIR/$(date +%F).log"
CURRENT_STAGE="初始化"
exec >>"$LOG_FILE" 2>&1

log() {
  print -r -- "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $*"
}

send_text() {
  local text="$1"
  "$OPENCLAW_BIN" message send \
    --channel "$TARGET_CHANNEL" \
    --target "$TARGET_CHAT_ID" \
    --message "$text" >/dev/null 2>&1 || true
}

cleanup() {
  rm -f "$TMP_DIR/summary-prompt.txt" "$TMP_DIR/changelog-section.md" "$TMP_DIR/update-status-before.json" "$TMP_DIR/update-status-after.json"
}
trap cleanup EXIT

send_failure_notice() {
  local stage="$1"
  local detail="$2"
  local suggestion="$3"
  send_text "OpenClaw 夜间升级翻车了 😵\n时间：$RUN_TS\n阶段：$stage\n情况：$detail\n建议先看：$suggestion\n日志位置：$LOG_FILE"
}

on_error() {
  local line="$1"
  log "ERROR at line $line (stage=$CURRENT_STAGE)"
  send_failure_notice "$CURRENT_STAGE" "脚本执行异常（line $line）" "openclaw gateway status；必要时看 ~/.openclaw/.logs/daily-update-watch.stderr.log"
}
trap 'on_error $LINENO' ERR

json_get() {
  local expr="$1"
  local file="$2"
  node -e '
    const fs = require("fs");
    const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const expr = process.argv[2].split(".");
    let cur = data;
    for (const key of expr) {
      if (!key) continue;
      cur = cur?.[key];
    }
    if (cur === undefined || cur === null) process.exit(2);
    process.stdout.write(String(cur));
  ' "$file" "$expr"
}

extract_changelog_section() {
  local version="$1"
  local changelog_file="$2"
  local out_file="$3"
  awk -v ver="$version" '
    $0 == "## " ver { in_section = 1 }
    in_section {
      if ($0 ~ /^## / && $0 != "## " ver && printed) exit
      print
      printed = 1
    }
  ' "$changelog_file" > "$out_file"
}

wait_for_gateway() {
  local attempts=60
  local sleep_seconds=5
  local i=1
  while (( i <= attempts )); do
    if "$OPENCLAW_BIN" gateway status >/dev/null 2>&1; then
      return 0
    fi
    sleep "$sleep_seconds"
    (( i++ ))
  done
  return 1
}

patch_gateway_plist() {
  local old_ver="$1" new_ver="$2"
  local plist_file="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
  [[ -f "$plist_file" ]] || { log "Gateway plist not found, skipping patch"; return 0; }

  # Find the new entry.js path in pnpm store
  local new_entry
  new_entry="$(find "$HOME/Library/pnpm/global" -path "*openclaw@${new_ver}*/dist/entry.js" -print -quit 2>/dev/null)"
  if [[ -z "$new_entry" ]]; then
    log "WARNING: Could not find entry.js for $new_ver in pnpm store; plist not patched"
    return 0
  fi

  # Find the old entry.js path currently in plist
  local old_entry
  old_entry="$(grep -o '/Users/[^<]*openclaw@[^<]*/dist/entry.js' "$plist_file" | head -1)"
  if [[ -z "$old_entry" ]]; then
    log "WARNING: Could not find entry.js path in plist; plist not patched"
    return 0
  fi

  if [[ "$old_entry" == "$new_entry" ]]; then
    log "Plist already points to $new_ver; no patch needed"
    return 0
  fi

  # Replace entry.js path
  sed -i '' "s|${old_entry}|${new_entry}|g" "$plist_file"
  # Update version comment and env var
  sed -i '' "s|OpenClaw Gateway (v${old_ver})|OpenClaw Gateway (v${new_ver})|g" "$plist_file"
  sed -i '' "s|OPENCLAW_SERVICE_VERSION</key>.*<string>${old_ver}|OPENCLAW_SERVICE_VERSION</key>\n    <string>${new_ver}|g" "$plist_file"

  log "Plist patched: $old_entry -> $new_entry"
}

main() {
  log "Nightly update watch started"

  CURRENT_STAGE="检查更新状态"
  "$OPENCLAW_BIN" update status --json > "$TMP_DIR/update-status-before.json"

  local available before_version latest_version
  before_version="$($OPENCLAW_BIN --version | awk '{print $2}')"
  available="false"
  if json_get 'availability.available' "$TMP_DIR/update-status-before.json" >/tmp/openclaw-available.$$ 2>/dev/null; then
    available="$(cat /tmp/openclaw-available.$$)"
    rm -f /tmp/openclaw-available.$$
  fi

  if [[ "$available" != "true" ]]; then
    log "No update available; exiting"
    return 0
  fi

  latest_version="$(json_get 'availability.latestVersion' "$TMP_DIR/update-status-before.json" 2>/dev/null || true)"
  log "Update available: ${before_version} -> ${latest_version:-unknown}"

  local update_output_file="$LOG_DIR/update-$(date +%F-%H%M%S).json"
  CURRENT_STAGE="执行升级"
  if ! "$OPENCLAW_BIN" update --yes --json > "$update_output_file" 2>&1; then
    log "Update command failed"
    send_failure_notice "执行升级" "从 $before_version 升到 ${latest_version:-未知} 时失败" "tail -n 80 $update_output_file；再跑 openclaw update status"
    return 1
  fi

  CURRENT_STAGE="更新 Gateway plist 路径"
  log "Patching gateway plist to point to new version"
  patch_gateway_plist "$before_version" "$after_version"

  CURRENT_STAGE="重启 Gateway 加载新版本"
  log "Restarting gateway with updated plist"
  "$OPENCLAW_BIN" gateway restart >/dev/null 2>&1 || true

  CURRENT_STAGE="等待 Gateway 重启恢复"
  log "Update command completed; waiting for gateway"
  if ! wait_for_gateway; then
    log "Gateway did not come back in time"
    send_failure_notice "等待 Gateway 重启恢复" "升级命令跑完了，但服务 5 分钟内没完全恢复" "openclaw gateway status；必要时 openclaw gateway restart"
    return 1
  fi

  CURRENT_STAGE="读取升级后状态"
  "$OPENCLAW_BIN" update status --json > "$TMP_DIR/update-status-after.json"

  local after_version root_after changelog_file section_file prompt_file summary_text
  after_version="$($OPENCLAW_BIN --version | awk '{print $2}')"
  root_after="$(json_get 'update.root' "$TMP_DIR/update-status-after.json")"
  changelog_file="$root_after/CHANGELOG.md"
  section_file="$TMP_DIR/changelog-section.md"
  prompt_file="$TMP_DIR/summary-prompt.txt"

  CURRENT_STAGE="提取更新日志"
  if [[ -f "$changelog_file" ]]; then
    extract_changelog_section "$after_version" "$changelog_file" "$section_file"
  else
    : > "$section_file"
  fi

  cat > "$prompt_file" <<EOF
你现在要生成一条发给爸爸的 OpenClaw 升级通知。

背景：
- 升级前版本：$before_version
- 升级后版本：$after_version
- 使用环境：macOS、stable 通道、Telegram 私聊、Gateway 由 LaunchAgent 托管
- 你的目标：替爸爸节省阅读 changelog 的时间，不要照抄原文，不要贴大段日志。

请完成下面的事：
1. 读取这个文件：$section_file
2. 如果上面的文件内容为空，再读取这个文件里对应版本的小节：$changelog_file
3. 用中文输出最终要发送的消息正文

输出要求：
- 不要用表格
- 不要贴原始 changelog 大段引用
- 语气自然、清晰、像靠谱助手，不要官话
- 明确告诉他：这版最值得关注的点是什么
- 把改动翻译成人话，优先解释“对他有什么实际影响”
- 如果多数改动只是底层修复，也请直说，不要硬吹
- 最后必须给一个明确结论：
  - “需不需要你额外操作：需要 / 不需要”
  - 如果需要，写清楚原因；如果不需要，也写清楚为什么

建议结构：
- 第一句：已更新到什么版本，值不值得关注
- 然后 3-5 条要点
- 最后 1 条“需不需要你额外操作”

总长度控制在 180-360 字。
只输出最终消息正文，不要解释你的步骤。
EOF

  CURRENT_STAGE="生成人话版更新摘要"
  summary_text="$($OPENCLAW_BIN agent --session-id nightly-openclaw-update-summary --message "$(cat "$prompt_file")" --timeout 180 | tr -d '\r')"

  if [[ -z "${summary_text// }" ]]; then
    summary_text="OpenClaw 已从 $before_version 更新到 $after_version。更新完成了，但这次自动解读没成功；我明早可以再帮你把这版重点捋成人话。"
  fi

  CURRENT_STAGE="发送升级摘要"
  send_text "$summary_text"
  log "Summary delivered"
}

main "$@"
