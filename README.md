# group-openrouter-skillshare

unfoldingWord's shared Claude Code plugin marketplace: OpenRouter setup and a
place for shared skills.

Add the marketplace, then install plugins from it:

```
/plugin marketplace add unfoldingWord-box3/group-openrouter-skillshare
```

## Plugins

| Plugin | Install | What it does |
|---|---|---|
| [or-delegate](plugins/or-delegate/README.md) | `/plugin install or-delegate@uw-skillshare` | Delegates bulk generation and bulk reading to cheap OpenRouter models (your own key) to save Claude subscription quota. |

New plugins go in `plugins/<name>/` and get an entry in
`.claude-plugin/marketplace.json`.
