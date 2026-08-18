#!/usr/bin/env bash
# status.sh - summarize or-delegate spend from ~/.claude/or-delegate/usage.jsonl:
# calls, tokens, and cost for today and the last 7 days, broken down by model.
set -euo pipefail

LOG="$HOME/.claude/or-delegate/usage.jsonl"
command -v jq >/dev/null 2>&1 || { echo "or-delegate: 'jq' is required but not installed." >&2; exit 1; }

if [ ! -s "$LOG" ]; then
  echo "No delegated calls logged yet (nothing at $LOG)."
  exit 0
fi

jq -rs '
  def money: (. * 1000000 | round) as $u
    | "$\($u / 1000000 | floor).\(($u % 1000000 + 1000000) | tostring | .[1:])";
  def table:
    (group_by(.model)
     | map("  \(.[0].model)  calls=\(length)  tokens_in=\(map(.tokens_in) | add)  tokens_out=\(map(.tokens_out) | add)  cost=\(map(.cost) | add | money)")
     | .[]),
    "  total: \(map(.cost) | add | money) across \(length) calls";
  (now | strftime("%Y-%m-%d")) as $today
  | map(select(.ts and .model))
  | (map(select(.ts | startswith($today)))) as $day
  | (map(select(((.ts | fromdateiso8601?) // 0) >= (now - 7 * 86400)))) as $week
  | "Today (\($today) UTC):",
    (if $day == [] then "  no calls" else ($day | table) end),
    "",
    "Last 7 days:",
    (if $week == [] then "  no calls" else ($week | table) end)
' "$LOG"
