---
name: routing
description: Route bulk work to cheap OpenRouter models instead of doing it with Claude. Use BEFORE generating boilerplate, test scaffolds, docs, or repetitive code longer than ~80 lines, and BEFORE reading files or logs longer than ~500 lines that only need comprehension or summarizing. Also use when the user mentions delegating, OpenRouter, or saving Claude quota.
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/delegate.sh *)
---

# Delegation policy

Claude subscription tokens are the expensive resource. An external model's
output that comes back as a tool result costs roughly 5x less than Claude
generating the same content, and the generation itself lands on OpenRouter
billing. So: Claude decides and reviews; a cheap model types.

The tool is one script:

```
"${CLAUDE_PLUGIN_ROOT}/scripts/delegate.sh" --model <id> [--out <file>] [--system <text>] "<prompt>"
```

It reads the user's own OpenRouter key (env var, `~/.config/or-delegate/key`,
or `./.dev.vars`) and logs every call to `~/.claude/or-delegate/usage.jsonl`.
If it exits complaining about a missing key, tell the user to run
`/or-delegate:setup`.

## Model menu

The single editable source of truth for which models we trust. Pricing is per
1M tokens (in/out), checked 2026-08-18.

| Job | Model ID | Why |
|---|---|---|
| cheap-and-fast (default) | `google/gemini-2.5-flash-lite` | $0.10/$0.40, 1M context. Boilerplate, scaffolds, docs, summaries. |
| code-strong | `qwen/qwen3-coder` | $0.30/$1.00, 262k context. Real implementation work, tricky transforms. |
| long-context | `deepseek/deepseek-v4-flash` | $0.08/$0.16, 1M context. Summarizing huge files and logs. |
| stronger generalist | `openai/gpt-5-mini` | $0.25/$2.00, 400k context. Retry here when the cheap model's output is junk. |

## Delegate bulk generation (write-to-disk pattern)

When the task is generating more than ~80 lines of low-judgment content —
boilerplate, test scaffolds, documentation, repetitive transforms, fixture
data:

1. Write a precise prompt: the exact spec, relevant code excerpts pasted in
   (the model has no repo access), output format, and "output only the code,
   no prose".
2. Run `delegate.sh --model <id> --out <target-or-temp-file> "<prompt>"`.
   `--out` writes the completion to disk and prints only a ~5-line preview
   plus token/cost stats, so the bulk never enters this session.
3. Review the file with Read/Grep and fix what's wrong yourself — small edits
   are Claude work; a rotten result means one retry with a better prompt or a
   stronger model, then do it yourself.

## Delegate bulk reading

When a file or log is longer than ~500 lines and you only need comprehension
(what does it do, where is the error, what changed), don't read it raw:

```
cat big.log | "${CLAUDE_PLUGIN_ROOT}/scripts/delegate.sh" --model deepseek/deepseek-v4-flash \
  --system "Summarize for a developer. Preserve exact error messages, line numbers, and identifiers." \
  "Summarize this log and list every distinct error with its first occurrence."
```

Read the summary; open the raw file only for the specific regions the summary
points at.

## When NOT to delegate

Do these yourself, always:

- Judgment calls: architecture, API design, naming, tradeoffs, planning.
- Security-sensitive code: auth, crypto, permissions, input validation,
  anything handling secrets.
- Anything needing whole-repo context — the delegated model sees only what
  the prompt contains.
- Small work: under ~80 lines generated or ~500 lines read, delegation
  overhead beats the savings.
- Final review. Delegated output is a draft. Claude owns what gets committed.

Never send secrets, keys, or private user data in a prompt: it goes to
OpenRouter and whichever provider serves the model.
