#!/bin/bash
# ZenMux Status Line for Claude Code
# Line 1: session info (model, dir, git, context remaining, duration)
# Line 2: ZenMux account (plan, quota usage, PAYG wallet balance)
# Requires: curl, jq; ZENMUX_MANAGEMENT_KEY env var for account data

set -o pipefail

# ── Colors ───────────────────────────────────────────────────────────
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
MAGENTA='\033[35m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Read Claude Code session data from stdin ─────────────────────────
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

# ── Context remaining bar (inverted: full bar = plenty of room) ──────
REMAIN_PCT=$(( 100 - USED_PCT ))
[ "$REMAIN_PCT" -lt 0 ] && REMAIN_PCT=0

if [ "$REMAIN_PCT" -le 10 ] 2>/dev/null; then CTX_COLOR="$RED"
elif [ "$REMAIN_PCT" -le 30 ] 2>/dev/null; then CTX_COLOR="$YELLOW"
else CTX_COLOR="$GREEN"; fi

BAR_WIDTH=10
CTX_FILLED=$(( REMAIN_PCT * BAR_WIDTH / 100 ))
CTX_EMPTY=$(( BAR_WIDTH - CTX_FILLED ))
CTX_BAR=""
[ "$CTX_FILLED" -gt 0 ] && printf -v FILL "%${CTX_FILLED}s" && CTX_BAR="${FILL// /█}"
[ "$CTX_EMPTY" -gt 0 ] && printf -v PAD "%${CTX_EMPTY}s" && CTX_BAR="${CTX_BAR}${PAD// /░}"

# ── Duration formatting ──────────────────────────────────────────────
MINS=$(( DURATION_MS / 60000 ))
SECS=$(( (DURATION_MS % 60000) / 1000 ))

# ── Git branch (cached per session, 5s TTL) ─────────────────────────
SESSION_ID=$(echo "$input" | jq -r '.session_id // "default"')
GIT_CACHE="/tmp/zenmux-sl-git-${SESSION_ID}"
GIT_CACHE_AGE=5

cache_is_stale() {
    local file=$1 max_age=$2
    [ ! -f "$file" ] && return 0
    local now; now=$(date +%s)
    local mtime; mtime=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0)
    [ $(( now - mtime )) -gt "$max_age" ]
}

if cache_is_stale "$GIT_CACHE" "$GIT_CACHE_AGE"; then
    if git rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH=$(git branch --show-current 2>/dev/null)
        DIRTY=""
        [ -n "$(git status --porcelain 2>/dev/null | head -1)" ] && DIRTY="*"
        echo "${BRANCH}${DIRTY}" > "$GIT_CACHE"
    else
        echo "" > "$GIT_CACHE"
    fi
fi
GIT_INFO=$(cat "$GIT_CACHE" 2>/dev/null || echo "")

# ── Line 1: Claude session info ─────────────────────────────────────
GIT_PART=""
[ -n "$GIT_INFO" ] && GIT_PART=" ${DIM}|${RESET} 🌿 ${GIT_INFO}"

printf '%b' "${CYAN}${BOLD}[${MODEL}]${RESET} 📁 ${DIR##*/}${GIT_PART} ${DIM}|${RESET} ctx ${CTX_COLOR}${CTX_BAR}${RESET} ${REMAIN_PCT}% ${DIM}|${RESET} ⏱ ${MINS}m${SECS}s\n"

# ── ZenMux account data (Line 2) ────────────────────────────────────
# If management key is not set, show a setup hint
if [ -z "$ZENMUX_MANAGEMENT_KEY" ]; then
    printf '%b' "${DIM}⚙ Set${RESET} ${YELLOW}ZENMUX_MANAGEMENT_KEY${RESET} ${DIM}to display account data →${RESET} ${CYAN}zenmux.ai/platform/management${RESET}\n"
    exit 0
fi

# Cache config: shared across sessions, 120s TTL
ZENMUX_CACHE="/tmp/zenmux-sl-account-cache"
ZENMUX_CACHE_AGE=120

if cache_is_stale "$ZENMUX_CACHE" "$ZENMUX_CACHE_AGE"; then
    # Fetch subscription detail and PAYG balance in parallel
    SUB_TMP=$(mktemp)
    PAYG_TMP=$(mktemp)

    curl -s --max-time 5 "https://zenmux.ai/api/v1/management/subscription/detail" \
        -H "Authorization: Bearer $ZENMUX_MANAGEMENT_KEY" > "$SUB_TMP" &
    PID_SUB=$!

    curl -s --max-time 5 "https://zenmux.ai/api/v1/management/payg/balance" \
        -H "Authorization: Bearer $ZENMUX_MANAGEMENT_KEY" > "$PAYG_TMP" &
    PID_PAYG=$!

    wait $PID_SUB $PID_PAYG 2>/dev/null

    # Merge into a single cache JSON
    SUB_DATA=$(cat "$SUB_TMP")
    PAYG_DATA=$(cat "$PAYG_TMP")
    rm -f "$SUB_TMP" "$PAYG_TMP"

    # Validate subscription response before caching
    if echo "$SUB_DATA" | jq -e '.data' > /dev/null 2>&1; then
        jq -n --argjson sub "$SUB_DATA" --argjson payg "$PAYG_DATA" \
            '{sub: $sub, payg: $payg}' > "$ZENMUX_CACHE" 2>/dev/null
    fi
fi

# If no cache available, skip ZenMux line
[ ! -f "$ZENMUX_CACHE" ] && exit 0

CACHED=$(cat "$ZENMUX_CACHE")

# ── Parse subscription data ──────────────────────────────────────────
PLAN_RAW=$(echo "$CACHED" | jq -r '.sub.data.plan.tier // "—"')
PLAN=$(echo "$PLAN_RAW" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
STATUS=$(echo "$CACHED" | jq -r '.sub.data.account_status // "unknown"')

# 5-hour quota (usage_percentage is a 0–1 decimal)
FIVE_H_PCT=$(echo "$CACHED" | jq -r '.sub.data.quota_5_hour.usage_percentage // 0')
FIVE_H_PCT_INT=$(echo "$FIVE_H_PCT" | awk '{printf "%.0f", $1 * 100}')

# 7-day quota
SEVEN_D_PCT=$(echo "$CACHED" | jq -r '.sub.data.quota_7_day.usage_percentage // 0')
SEVEN_D_PCT_INT=$(echo "$SEVEN_D_PCT" | awk '{printf "%.0f", $1 * 100}')

# ── Build quota mini-bars (usage: higher = worse) ───────────────────
make_usage_bar() {
    local pct=$1 width=5
    local filled=$(( pct * width / 100 ))
    [ "$filled" -gt "$width" ] && filled=$width
    local empty=$(( width - filled ))
    local color
    if [ "$pct" -ge 90 ]; then color="$RED"
    elif [ "$pct" -ge 70 ]; then color="$YELLOW"
    else color="$GREEN"; fi
    local bar=""
    [ "$filled" -gt 0 ] && printf -v f "%${filled}s" && bar="${f// /█}"
    [ "$empty" -gt 0 ] && printf -v e "%${empty}s" && bar="${bar}${e// /░}"
    printf '%b' "${color}${bar}${RESET}"
}

FIVE_BAR=$(make_usage_bar "$FIVE_H_PCT_INT")
SEVEN_BAR=$(make_usage_bar "$SEVEN_D_PCT_INT")

# ── Parse PAYG wallet balance ────────────────────────────────────────
PAYG_TOTAL=$(echo "$CACHED" | jq -r '.payg.data.total_credits // empty')
PAYG_PART=""
if [ -n "$PAYG_TOTAL" ] && [ "$PAYG_TOTAL" != "null" ]; then
    PAYG_FMT=$(printf '$%.2f' "$PAYG_TOTAL")
    # 💳 + "Bal" makes it clear this is available wallet balance, not consumption
    PAYG_PART=" ${DIM}|${RESET} 💳 Bal ${GREEN}${BOLD}${PAYG_FMT}${RESET}"
fi

# ── Status indicator ─────────────────────────────────────────────────
if [ "$STATUS" = "healthy" ]; then
    STATUS_PART="${MAGENTA}${BOLD}⚡ ${PLAN}${RESET}"
else
    STATUS_PART="${RED}${BOLD}⚠ ${PLAN}${RESET}"
fi

# ── Line 2: ZenMux account info ─────────────────────────────────────
printf '%b' "${STATUS_PART} ${DIM}|${RESET} 5h ${FIVE_BAR} ${FIVE_H_PCT_INT}% ${DIM}·${RESET} 7d ${SEVEN_BAR} ${SEVEN_D_PCT_INT}%${PAYG_PART}\n"
