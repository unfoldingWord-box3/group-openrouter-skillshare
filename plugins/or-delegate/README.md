# or-delegate

Hand bulk work to cheap OpenRouter models instead of burning Claude
subscription quota. Claude decides and reviews; a model costing cents per
million tokens does the typing. Every call is billed to your own OpenRouter
key and logged locally, and large outputs are written to disk so the Claude
session never ingests them.

## Install (users)

```
/plugin marketplace add unfoldingWord-box3/group-openrouter-skillshare
/plugin install or-delegate@uw-skillshare
```

Then run `/or-delegate:setup` once to connect your own OpenRouter API key.
Keys are per-person; nothing is shared and nothing lives in any repo.

Requirements on the machine: `bash`, `curl`, `jq`. Setup checks for them.

## Commands

| Command | What it does |
|---|---|
| `/or-delegate:setup` | Walks you through creating and storing an OpenRouter key, then fires a test call. |
| `/or-delegate:delegate <task>` | Explicitly delegates one task to a cheap model; Claude reviews the result. |
| `/or-delegate:status` | Spend today and this week, broken down by model, from the local usage log. |

Beyond the commands, the plugin ships a `routing` skill that Claude applies
on its own: generation longer than ~80 lines and read-only comprehension of
files beyond ~500 lines get routed through `scripts/delegate.sh`
automatically. The vetted model menu lives in one place,
[skills/routing/SKILL.md](skills/routing/SKILL.md) — edit it there.

There is also an optional `drafter` agent (runs on Haiku) that orchestrates
big fully-specified drafting jobs: cheap Claude driving, OpenRouter
generating.

## Key resolution and storage

`scripts/delegate.sh` looks for a key in this order:

1. `OPENROUTER_API_KEY` environment variable
2. `~/.config/or-delegate/key` (created by setup, `chmod 600`)
3. an `OPENROUTER_API_KEY=...` line in `./.dev.vars` in the project

Hosted cloud sessions (claude.ai/code web and mobile) have no persistent home
directory, so there use option 3 — a git-ignored `.dev.vars` file — or the
org's managed environment settings.

Usage is logged one JSON line per call to `~/.claude/or-delegate/usage.jsonl`
(timestamp, model, prompt length, tokens in/out, cost). It stays on your
machine.

## For marketplace admins

This repo doubles as the marketplace: `.claude-plugin/marketplace.json` at
the repo root lists this plugin with a relative source. To add it to a
different private marketplace instead, add an entry to that marketplace's
`marketplace.json`:

```json
{
  "name": "or-delegate",
  "source": { "source": "github", "repo": "unfoldingWord-box3/group-openrouter-skillshare", "path": "plugins/or-delegate" },
  "description": "Delegate bulk work to cheap OpenRouter models."
}
```

Two things admins must keep in mind:

- **Network allowlist:** hosted cloud sessions can only reach allowlisted
  hosts. Keep `openrouter.ai` on the org's network allowlist (the API lives
  at `openrouter.ai/api/v1`, not on an `api.` subdomain).
- **No stdio MCP:** this plugin is deliberately plain bash + HTTPS, because
  hosted cloud sessions do not run stdio MCP servers. Don't "upgrade" it to
  one.

## Why this is allowed (and pooling keys is not)

This plugin only ever talks to OpenRouter with each user's own OpenRouter
key. It never touches Anthropic APIs with subscription credentials and never
routes subscription OAuth through third-party services — that is technically
blocked and against Anthropic's terms of service. Keep it that way.
