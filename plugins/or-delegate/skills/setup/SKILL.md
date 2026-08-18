---
name: setup
description: Set up an OpenRouter API key for the or-delegate plugin and verify it with a test call
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/delegate.sh *)
---

Walk the user through connecting their own OpenRouter key. The key must never
appear in this chat, in any repo, or in any log.

1. Check prerequisites: `curl` and `jq` must be installed (`command -v curl jq`).
   If either is missing, give the install command for the user's platform and
   stop until it's installed.

2. Point the user at https://openrouter.ai/settings/keys — they sign up (any
   login works), add a few dollars of credit or set a spending limit, and
   create an API key (it starts with `sk-or-`).

3. Have the user store the key themselves. Do not ask them to paste the key
   into the chat, and don't have them put it on a command line either (it
   would land in shell history). Give them this command to run in their own
   terminal — it prompts silently for the key, so nothing sensitive is typed
   into history:

   ```bash
   mkdir -p ~/.config/or-delegate && read -rsp "OpenRouter key: " k && printf '%s' "$k" > ~/.config/or-delegate/key && chmod 600 ~/.config/or-delegate/key && unset k && echo " stored"
   ```

   Alternatives, if they prefer: export `OPENROUTER_API_KEY` in their shell
   profile, or — for hosted cloud sessions where the home directory doesn't
   persist — put `OPENROUTER_API_KEY=sk-or-...` in a `.dev.vars` file in the
   project, or use the org's managed environment settings. If they choose
   `.dev.vars`, first confirm the project's `.gitignore` actually ignores
   `.dev.vars` (add the line if missing) so the key can never be committed.

4. Once they say it's stored, verify with a real test call to the cheapest
   menu model:

   ```
   ${CLAUDE_PLUGIN_ROOT}/scripts/delegate.sh --model google/gemini-2.5-flash-lite "Reply with exactly: or-delegate is working"
   ```

5. On success, show the cost stats the script printed (the test costs a tiny
   fraction of a cent) and tell them the two commands they'll actually use:
   `/or-delegate:delegate <task>` and `/or-delegate:status`. On failure, read
   the script's error message — it says which of the three key locations were
   checked or what OpenRouter rejected — and fix that specific thing.

6. Offer to make delegation a standing behavior: the snippet at
   `${CLAUDE_PLUGIN_ROOT}/claude-md-snippet.md` teaches sessions to prefer
   or-delegate for bulk work and to delegate more aggressively as weekly
   Claude quota runs low. With the user's OK, append its markdown body (skip
   the HTML comment at the top) to their `~/.claude/CLAUDE.md`, or to the
   project's `CLAUDE.md` if they'd rather scope it. Skip silently if an
   or-delegate section is already there.
