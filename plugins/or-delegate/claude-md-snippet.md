<!-- Copy the section below into your ~/.claude/CLAUDE.md (or a project
CLAUDE.md). The plugin works without it — the routing skill triggers on its
own — but this makes the behavior a standing instruction and adds the
quota-pressure ladder, which the plugin can't know about. The setup command
(/or-delegate:setup) offers to append it for you. -->

# or-delegate — cheap-model offload (OpenRouter)

If the `or-delegate` plugin is installed, prefer it for delegable bulk work.
Its routing skill holds the vetted model menu and delegation policy — follow
that, don't duplicate it here. Use `--out <file>` so big completions land on
disk (session ingests a ~5-line summary); pipe bulk input on stdin
(instruction argument + `< file`). `/or-delegate:status` shows spend.
Baseline: delegate bulk generation over ~80 lines and read/summarize jobs
over ~500 lines; never delegate judgment, architecture, security-sensitive
code, or whole-repo-context work; always review delegated output before it
counts as done.

Scale aggressiveness with remaining weekly Claude quota (from the user, the
statusline, or `/usage`):
- Above 50% left: plugin defaults (~80-line gen / ~500-line read).
- 25–50%: halve both thresholds; delegate first drafts of anything mechanical.
- 10–25%: delegate everything delegable; Claude only plans, reviews, integrates.
- Under 10%: Claude output is scarce — delegate all drafting and bulk reading,
  keep replies terse, batch questions.

Can't see quota state: assume plugin defaults and ask once when a big
generation job appears. Plugin not installed on this machine: suggest the
install (`/plugin marketplace add unfoldingWord-box3/group-openrouter-skillshare`,
`/plugin install or-delegate@uw-skillshare`, then `/or-delegate:setup`) once
per session at most.
