---
name: claude-codex-dual-pass
description: Use when the user asks Codex to run a Claude Code command and then independently perform the same workflow itself, especially `cc /slash-command`, "run Claude Code command", "Claude edits allowed", "full permissions", "then Codex do the same", "dual pass", or "/finalize".
---

# Claude + Codex Dual Pass

Use this skill when a task explicitly combines a Claude Code slash command with a Codex-owned second pass. The preferred short syntax is `cc <slash-command> [args] [permission-modifier]`.

`cc` always means "run Claude Code first, then Codex independently performs the same markdown-defined workflow and verifies." It never means Claude-only. Claude Code may run first, but Codex remains responsible for reading the command instructions, inspecting the resulting diff, performing the same workflow independently, and verifying the final state.

## Short Syntax

Preferred invocations:

```text
cc /finalize
cc /project:test
cc /user:security-audit
cc /project:build --fast
```

Permission modifiers may be appended to the request:

- `cc /cmd read-only` -> Claude `--permission-mode plan`; no Claude edits.
- `cc /cmd accept` or `cc /cmd edits` -> Claude `--permission-mode acceptEdits`.
- `cc /cmd full` or `cc /cmd bypass` -> Claude `--permission-mode bypassPermissions`.

Treat `read-only`, `accept`, `edits`, `full`, and `bypass` as control words for Codex when they appear as permission modifiers; do not pass those modifier words to Claude as part of the slash command.

For bare `cc /cmd`:

- Use `--permission-mode bypassPermissions` by default.
- Read the command markdown to understand the workflow, expected outputs, and verification steps, but do not use it to downgrade the default Claude permission mode.
- Only use `plan` or `acceptEdits` when the user explicitly provides a permission modifier such as `read-only`, `accept`, or `edits`.

## Invocation Samples

Short syntax is preferred:

```text
cc /finalize full
```

```text
cc /project:test accept
```

```text
cc /user:security-audit read-only
```

Equivalent long form remains valid when the user wants to be explicit:

Read/report only:

```text
Use $claude-codex-dual-pass. Run Claude Code /finalize read-only, then Codex independently perform the same checklist.
```

Edit-allowed project command:

```text
Use $claude-codex-dual-pass. Run Claude Code /project:test with edit permissions, then Codex review the diff and run the same test workflow itself.
```

User/global command:

```text
Use $claude-codex-dual-pass. Run Claude Code /user:security-audit read-only, then Codex inspect the command markdown and perform its own review pass.
```

## Permission Mapping

- Read/report-only, `read-only`: run Claude with `--permission-mode plan` and explicitly tell Claude not to edit files.
- Edit permissions, `accept`, `edits`: run Claude with `--permission-mode acceptEdits`.
- Full permissions, `full`, `bypass`: run Claude with `--permission-mode bypassPermissions`.
- Only use `--dangerously-skip-permissions` when the user explicitly asks for that exact bypass.

For bare `cc /cmd`, always run Claude with `--permission-mode bypassPermissions`. The command markdown is still required context for Codex's independent pass, but it is not used to infer a safer default mode.

## Command Resolution

Resolve and read the command markdown before running Claude so Codex understands the workflow:

- `/project:name` resolves to `<project-root>/.claude/commands/name.md`.
- `/user:name` resolves to `$HOME/.claude/commands/name.md`.
- Bare `/name` resolves in this order:
  1. `<project-root>/.claude/commands/name.md`
  2. `$HOME/.claude/commands/name.md`
  3. project-linked shared command paths, such as `<project-root>/.claude/shared/**/commands/name.md` or another repo-documented shared command path

For namespaced commands, map colons to path segments where the command layout uses subdirectories. If multiple candidates exist, prefer explicit scope from the user (`/project:`, `/user:`) and report which file was used.

## Required Workflow

1. Capture baseline state:
   - `git status --short`
   - focused `git diff --stat` when there are existing changes
2. Parse `cc` shorthand if used, resolve the Claude command markdown, and summarize its intended workflow.
3. Run Claude Code exactly within the requested permission envelope:
   - Bare `cc /cmd`: `claude -p '<slash-command and args>' --permission-mode bypassPermissions`
   - Explicit permission modifier: `claude -p '<slash-command and args>' --permission-mode <mapped-mode>`
4. After Claude exits:
   - capture Claude output,
   - run `git status --short`,
   - inspect `git diff` to identify Claude-visible changes.
5. Codex then independently performs the same command workflow:
   - re-read the command markdown,
   - inspect Claude changes,
   - make additional Codex edits if needed and allowed,
   - run the repo-appropriate verification commands.
6. Final response must separate:
   - Claude Code changes,
   - Codex changes after Claude,
   - verification results,
   - skipped or blocked steps.

Do not stop after Claude says the task is complete. Do not outsource final verification to Claude.

## Waiting For Claude

Claude Code can work quietly for a long time. Treat no stdout/stderr as normal unless the process has exited or produced an actual error.

- Do not call a running Claude process stalled because it is silent.
- Do not interrupt, kill, or retry Claude solely because elapsed time is long or output is quiet.
- Poll or wait until Claude exits, unless the user explicitly interrupts/stops it or the process actually exits/errors.
- User-facing progress updates should say "Claude is still running" or "Claude is working quietly". Avoid "stalled" unless there is concrete evidence of a deadlock beyond silence.

## AGENTS.md Integration

For persistent project-level instructions, use [references/agents-snippet.md](references/agents-snippet.md).

Check whether a project has the managed snippet:

```bash
$CODEX_HOME/skills/claude-codex-dual-pass/scripts/check_agents_snippet.sh <project-root>
```

Insert or update the managed snippet explicitly:

```bash
$CODEX_HOME/skills/claude-codex-dual-pass/scripts/apply_agents_snippet.sh <project-root>
```

The apply script only edits the managed marker block or appends a new block. It does not silently rewrite unrelated AGENTS.md content.
