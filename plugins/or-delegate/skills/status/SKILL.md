---
name: status
description: Report OpenRouter delegation spend for today and the last 7 days, by model
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/status.sh)
---

Run exactly (unquoted, no extra arguments, so it matches the pre-approved
permission rule):

```
${CLAUDE_PLUGIN_ROOT}/scripts/status.sh
```

Show the user its output as-is (it is already grouped by model for today and
the last 7 days), then add one plain sentence putting the total in context,
e.g. how it compares to what the same output tokens would have cost on the
Claude subscription. If the script says nothing is logged yet, say so and
mention `/or-delegate:delegate` as the way to start.
