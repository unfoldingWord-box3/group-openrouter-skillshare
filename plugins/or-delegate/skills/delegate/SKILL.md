---
name: delegate
description: Explicitly delegate one task to a cheap OpenRouter model
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/delegate.sh *)
---

Delegate this task to a cheap OpenRouter model instead of doing it yourself:

$ARGUMENTS

Follow the delegation policy and model menu in
`${CLAUDE_PLUGIN_ROOT}/skills/routing/SKILL.md` (read it if it is not already
in context). In short:

1. Pick the cheapest model that fits the job from the menu.
2. Build a self-contained prompt — paste in any code or context the model
   needs, since it cannot see this repo.
3. For output longer than ~80 lines, use `--out <file>` so the completion
   lands on disk, then review the file rather than regenerating it.
4. Report to the user: what was delegated, to which model, the cost stats the
   script printed, and your review verdict on the result.

If the script reports a missing API key, stop and tell the user to run
`/or-delegate:setup`.
