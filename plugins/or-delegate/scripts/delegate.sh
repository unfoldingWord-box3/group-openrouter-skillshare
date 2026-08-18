#!/usr/bin/env bash
# delegate.sh - send one prompt to an OpenRouter model and return the completion.
# Part of the or-delegate plugin. Keeps bulk generation off the Claude subscription.
#
# Usage:
#   delegate.sh --model <openrouter-model-id> [--out <file>] [--system <text>] [--] "<prompt>"
#   cat prompt.txt | delegate.sh --model <openrouter-model-id> [--out <file>]
#
# With --out, the full completion goes to the file and only a short summary is
# printed, so the calling session never ingests the bulk output.
set -euo pipefail

API_URL="https://openrouter.ai/api/v1/chat/completions"
LOG_DIR="$HOME/.claude/or-delegate"
KEY_FILE="$HOME/.config/or-delegate/key"

die() { echo "or-delegate: $*" >&2; exit 1; }

for dep in curl jq; do
  command -v "$dep" >/dev/null 2>&1 ||
    die "'$dep' is required but not installed. Install it first (apt install $dep / brew install $dep / winget install $dep)."
done

MODEL="" OUT_FILE="" SYSTEM="" PROMPT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --model)  MODEL="${2:?--model needs a value}"; shift 2 ;;
    --out)    OUT_FILE="${2:?--out needs a value}"; shift 2 ;;
    --system) SYSTEM="${2:?--system needs a value}"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --) shift; PROMPT="$*"; break ;;
    --*) die "unknown option: $1 (put -- before a prompt that starts with --)" ;;
    *) [ -z "$PROMPT" ] || die "got more than one prompt argument - quote the whole prompt"
       PROMPT="$1"; shift ;;
  esac
done

[ -n "$MODEL" ] || die "--model is required, e.g. --model google/gemini-2.5-flash-lite (vetted options: the plugin's routing skill)"
# Prompt argument and stdin combine: argument first (the instruction), then
# stdin (the material), so `delegate.sh "summarize this" < big.log` works.
if [ ! -t 0 ]; then
  STDIN="$(cat)"
  if [ -n "$STDIN" ]; then
    if [ -n "$PROMPT" ]; then PROMPT="$PROMPT"$'\n\n'"$STDIN"; else PROMPT="$STDIN"; fi
  fi
fi
[ -n "$PROMPT" ] || die "no prompt given (pass it as an argument or on stdin)"

# Key lookup order: env var, per-user key file, then .dev.vars in the current
# directory or the git root (the .dev.vars route is how hosted cloud sessions
# supply a key).
KEY="${OPENROUTER_API_KEY:-}"
if [ -z "$KEY" ] && [ -f "$KEY_FILE" ]; then KEY="$(tr -d '[:space:]' < "$KEY_FILE")"; fi
if [ -z "$KEY" ]; then
  DEV_VARS=".dev.vars"
  [ -f "$DEV_VARS" ] || DEV_VARS="$(git rev-parse --show-toplevel 2>/dev/null || echo .)/.dev.vars"
  if [ -f "$DEV_VARS" ]; then
    KEY="$(sed -nE 's/^(export )?OPENROUTER_API_KEY=//p' "$DEV_VARS" | head -n1 \
           | sed -E "s/#.*//; s/['\"[:space:]]//g")"
  fi
fi
if [ -z "$KEY" ]; then
  cat >&2 <<'EOF'
or-delegate: no OpenRouter API key found. Looked for:
  1. the OPENROUTER_API_KEY environment variable
  2. ~/.config/or-delegate/key
  3. an OPENROUTER_API_KEY=... line in .dev.vars (current dir or git root)
Run /or-delegate:setup in Claude Code to create and store a key.
EOF
  exit 1
fi

# Prompt, request body, and auth header travel via temp files, never argv:
# argv has hard size limits (~32KB on Git Bash) and is visible to other
# processes on shared hosts.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
printf '%s' "$PROMPT" > "$TMP_DIR/prompt"
printf 'Authorization: Bearer %s\n' "$KEY" > "$TMP_DIR/auth"

jq -n --rawfile prompt "$TMP_DIR/prompt" --arg model "$MODEL" --arg system "$SYSTEM" '
  {model: $model,
   usage: {include: true},
   messages: ((if $system == "" then [] else [{role: "system", content: $system}] end)
              + [{role: "user", content: $prompt}])}' > "$TMP_DIR/body"

RESPONSE="$(curl -sS --max-time 600 "$API_URL" \
  -H @"$TMP_DIR/auth" \
  -H "Content-Type: application/json" \
  --data @"$TMP_DIR/body")" || die "could not reach openrouter.ai (network error)"

jq -e . >/dev/null 2>&1 <<<"$RESPONSE" ||
  die "OpenRouter returned non-JSON (gateway outage?). Response starts: $(head -c 200 <<<"$RESPONSE")"
ERROR="$(jq -r '.error.message // empty' <<<"$RESPONSE")"
[ -z "$ERROR" ] || die "OpenRouter returned an error: $ERROR"

# Content is usually a string but some models return an array of parts.
CONTENT="$(jq -r '(.choices[0].message.content // "")
  | if type == "array" then map(.text? // "") | join("") else . end' <<<"$RESPONSE")"

read -r TOKENS_IN TOKENS_OUT COST <<<"$(jq -r \
  '[.usage.prompt_tokens // 0, .usage.completion_tokens // 0, .usage.cost // 0] | @tsv' \
  <<<"$RESPONSE")" || true
: "${TOKENS_IN:=0}" "${TOKENS_OUT:=0}" "${COST:=0}"

# Log before the empty-content check: a billed call must show up in status
# even when the model returned nothing usable.
mkdir -p "$LOG_DIR"
jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg model "$MODEL" \
  --argjson prompt_chars "${#PROMPT}" --argjson tokens_in "$TOKENS_IN" \
  --argjson tokens_out "$TOKENS_OUT" --argjson cost "$COST" \
  '{ts: $ts, model: $model, prompt_chars: $prompt_chars,
    tokens_in: $tokens_in, tokens_out: $tokens_out, cost: $cost}' \
  >> "$LOG_DIR/usage.jsonl"

[ -n "$CONTENT" ] ||
  die "no text content in the completion (call logged to usage.jsonl, tokens_out=$TOKENS_OUT). Response starts: $(head -c 300 <<<"$RESPONSE")"

STATS="model=$MODEL tokens_in=$TOKENS_IN tokens_out=$TOKENS_OUT cost=\$$COST"
if [ -n "$OUT_FILE" ]; then
  mkdir -p "$(dirname "$OUT_FILE")"
  printf '%s\n' "$CONTENT" > "$OUT_FILE"
  echo "Wrote $(wc -l < "$OUT_FILE" | tr -d ' ') lines to $OUT_FILE"
  echo "First lines:"
  head -n 3 "$OUT_FILE" | cut -c1-120
  echo "$STATS"
else
  printf '%s\n' "$CONTENT"
  echo "[$STATS]" >&2
fi
