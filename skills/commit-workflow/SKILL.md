---
name: commit-workflow
description: Prepare and execute safe two-step Git commits in Codex by drafting a commit message, requesting explicit user approval, and only then committing. Use when the user asks to prepare a commit message, perform a commit, or run a two-step commit workflow. Do not use Claude slash commands or Claude CLI for this workflow.
---

# Commit Workflow

Use a strict two-step process: prepare first, commit second. Keep all commit actions non-interactive and Git-native.

## Triggering and Invocation

- Requests like `commit` or `do commit` are likely to trigger this skill via semantic matching.
- For deterministic invocation, use explicit phrasing such as `Use $commit-workflow. ...`.
- Two-step behavior is mandatory:
- First prepare and approve the commit message.
- Then execute the commit after explicit approval.

Examples:
- `Use $commit-workflow. Review changes and prepare commit message.`
- `Use $commit-workflow. Commit now with the approved message.`

## Hard Rules

- Do not use Claude slash commands such as `/commit-prepare` or `/commit-do`.
- Do not invoke Claude CLI for commit workflow tasks.
- Use non-interactive Git commands only.
- Never commit before explicit user approval of the drafted message.
- Never push automatically.

## Step 1: Prepare Commit Message

1. Run `git status --short` to inspect changed files.
2. Run `git diff` (or focused diffs) to inspect actual changes.
3. Run `git log -5 --oneline` to align with recent commit style.
4. Draft a commit message with these rules:
- Subject line max 50 characters.
- Imperative mood.
- No trailing period in subject.
- Exactly one blank line between subject and body.
- Hard-wrap every body line to 72 characters or less.
- Do not insert empty lines between body sentences.
- Explain what changed and why.
- Never include `Bump module version`.
- Never include AI attribution footers.
- Use this structure:
   ```text
   Subject line

   Single compact body paragraph wrapped at <=72 chars per line.
   Continue the same paragraph on next wrapped lines if needed.
   ```
5. Ticket handling:
- Default to non-ticket subject format.
- Use ticket-prefixed subject only if user explicitly requests it or provides a ticket ID.
6. Present the full draft commit message to the user and ask for explicit approval.
7. Do not commit in this step.

## Step 2: Commit After Approval

1. Re-check `git status --porcelain`.
2. If there are no changes, report that nothing can be committed and stop.
3. Stage with `git add .` unless the user requested narrower staging.
4. Commit using the approved message in multiline-safe form.
5. Run `git status --short` and show resulting state.
6. Ask whether the user wants to push.
7. Do not push unless explicitly requested.

## Expected Outcomes

- `prepare commit` requests produce a complete message draft and approval request.
- `commit now` requests run only after an approved message exists.
- The workflow remains Git-native and never depends on Claude command infrastructure.
