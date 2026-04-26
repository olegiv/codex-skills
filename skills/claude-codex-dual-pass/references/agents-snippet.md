<!-- codex-skill:claude-codex-dual-pass:start -->
### Claude Code + Codex Dual-Pass Workflow

When the user asks to run a Claude Code command and then have Codex do the same work, prefer the short `cc <slash-command> [args] [permission-modifier]` syntax:

```text
cc /finalize full
cc /project:test accept
cc /user:security-audit read-only
```

`cc` always means "Claude Code command plus Codex independent second pass", never Claude-only.

1. Resolve and read the relevant Claude command markdown before deciding the risk level.
2. Run Claude Code with the permission mode requested or inferred from the command markdown.
3. Capture Claude output, `git status --short`, and the resulting diff.
4. Codex must independently execute the same markdown-defined workflow, not merely trust Claude's result.
5. Codex owns final edits, final verification, and the final report.
6. The final report must separate Claude Code changes, Codex changes, verification results, and any skipped or blocked steps.

Permission modifiers: `read-only` -> `plan`, `accept`/`edits` -> `acceptEdits`, `full`/`bypass` -> `bypassPermissions`. For bare `cc /cmd`, use `acceptEdits` only when the command markdown clearly performs edits, fixes, updates, formatting, finalization, or check-and-repair work; use `plan` when it is clearly read-only. If risky or unclear, ask before running Claude.
<!-- codex-skill:claude-codex-dual-pass:end -->
