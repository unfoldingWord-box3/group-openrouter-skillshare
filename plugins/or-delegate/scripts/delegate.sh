#!/usr/bin/env bash
# delegate.sh - send one prompt to an OpenRouter model and return the completion.
# Part of the or-delegate plugin. Keeps bulk generation off the Claude subscription.
#
# Usage:
#   delegate.sh --model <openrouter-model-id> [--out <file>] [--system <text>] "<prompt>"
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
    --*) die "unknown option: $1" ;;
    *) PROMPT="$1"; shift ;;
  esac
done

[ -n "$MODEL" ] || die "--model is required, e.g. --model google/gemini-2.5-flash-lite (vetted options: the plugin's routing skill)"
if [ -z "$PROMPT" ]; then
  [ -t 0 ] && die "no prompt given (pass it as an argument or on stdin)"
  PROMPT="$(cat)"
fi
[ -n "$PROMPT" ] || die "prompt is empty"

# Key lookup order: env var, per-user key file, project-local .dev.vars
# (the last one is how hosted cloud sessions supply a key).
KEY="${OPENROUTER_API_KEY:-}"
if [ -z "$KEY" ] && [ -f "$KEY_FILE" ]; then KEY="$(tr -d '[:space:]' < "$KEY_FILE")"; fi
if [ -z "$KEY" ] && [ -f .dev.vars ]; then
  KEY="$(sed -n 's/^OPENROUTER_API_KEY=//p' .dev.vars | head -n1 | tr -d '"[:space:]')"
fi
if [ -z "$KEY" ]; then
  cat >&2 <<'EOF'
or-delegate: no OpenRouter API key found. Looked for:
  1. the OPENROUTER_API_KEY environment variable
  2. ~/.config/or-delegate/key
  3. an OPENROUTER_API_KEY=... line in ./.dev.vars
Run /or-delegate:setup in Claude Code to create and store a key.
EOF
  exit 1
fi

BODY="$(jq -n --arg model "$MODEL" --arg system "$SYSTEM" --arg prompt "$PROMPT" '
  {model: $model,
   usage: {include: true},
   messages: ((if $system == "" then [] else [{role: "system", content: $system}] end)
              + [{role: "user", content: $prompt}])}')"

RESPONSE="$(curl -sS --max-time 600 "$API_URL" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d "$BODY")" || die "could not reach openrouter.ai (network error)"

ERROR="$(jq -r '.error.message // empty' <<<"$RESPONSE")"
[ -z "$ERROR" ] || die "OpenRouter returned an error: $ERROR"
CONTENT="$(jq -r '.choices[0].message.content // empty' <<<"$RESPONSE")"
[ -n "$CONTENT" ] || die "empty completion. Raw response starts: $(head -c 300 <<<"$RESPONSE")"

read -r TOKENS_IN TOKENS_OUT COST <<<"$(jq -r \
  '[.usage.prompt_tokens // 0, .usage.completion_tokens // 0, .usage.cost // 0] | @tsv' <<<"$RESPONSE")"

mkdir -p "$LOG_DIR"
jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg model "$MODEL" \
  --argjson prompt_chars "${#PROMPT}" --argjson tokens_in "$TOKENS_IN" \
  --argjson tokens_out "$TOKENS_OUT" --argjson cost "$COST" \
  '{ts: $ts, model: $model, prompt_chars: $prompt_chars,
    tokens_in: $tokens_in, tokens_out: $tokens_out, cost: $cost}' \
  >> "$LOG_DIR/usage.jsonl"

STATS="model=$MODEL tokens_in=$TOKENS_IN tokens_out=$TOKENS_OUT cost=\$$COST"
if [ -n "$OUT_FILE" ]; then
  printf '%s\n' "$CONTENT" > "$OUT_FILE"
  echo "Wrote $(wc -l < "$OUT_FILE" | tr -d ' ') lines to $OUT_FILE"
  echo "First lines:"
  head -n 3 "$OUT_FILE" | cut -c1-120
  echo "$STATS"
else
  printf '%s\n' "$CONTENT"
  echo "[$STATS]" >&2
fi
