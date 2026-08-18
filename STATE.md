# STATE

## What this repo is

unfoldingWord's shared Claude Code plugin marketplace (`uw-skillshare`) and
the workspace for shared agentic-coding infrastructure. Plugins live in
`plugins/<name>/`, each with an entry in `.claude-plugin/marketplace.json`.
First plugin: `or-delegate` (delegate bulk work to cheap OpenRouter models).

## Gotchas

- Hosted cloud sessions (claude.ai/code web/mobile) do not run stdio MCP
  servers. Plugins here must stay bash/HTTP-first.
- The OpenRouter API host is `openrouter.ai` (`/api/v1`), not an `api.`
  subdomain. Org network allowlists for cloud sessions need `openrouter.ai`.
- Plugin command namespaces come from the `name` in plugin.json, so
  or-delegate ships `/or-delegate:setup|delegate|status`. Bare `/delegate`
  etc. also resolve when no other command claims the name.
- The vetted model menu (IDs, pricing, roles) lives in exactly one place:
  `plugins/or-delegate/skills/routing/SKILL.md`. Pricing checked 2026-08-18
  against the public `openrouter.ai/api/v1/models` endpoint.
- Per-user secrets and logs never enter this repo: keys go in
  `~/.config/or-delegate/key` (or `$OPENROUTER_API_KEY`, or a git-ignored
  `.dev.vars`); usage logs in `~/.claude/or-delegate/usage.jsonl`.
  `.gitignore` blocks `.dev.vars`, `*.key`, `usage.jsonl` defensively.

## Goals / open threads

- Team adoption of or-delegate: teammates install, add their own key,
  report spend via `/or-delegate:status`.
- Broader shared-infra decisions (billing posture, shared skills/memory,
  cloud dispatch) are pending; see the 2026-08 decision brief artifact
  (https://claude.ai/code/artifact/1e5bef2a-0c60-4b6c-842c-0302e527e15a).
