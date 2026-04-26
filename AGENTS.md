# AGENTS.md

## Scope

This repository contains shareable Codex skills and supporting tooling.

Primary mutable paths:

- `skills/**`
- `scripts/**`
- `.github/workflows/**`
- `README.md`, `CHANGELOG.md`, `LICENSE`, `AGENTS.md`

## Public-Safe Rules

All content must remain public-safe by default.

Must not contain:

- absolute local machine paths (`<local-home>/...`, `<local-temp>/...`)
- internal hostnames, project IDs, or usernames
- concrete secrets/tokens/passwords/private keys

Use placeholders:

- `$CODEX_HOME`, `<repo-root>`, `<project-id>`, `<username>`
- `<your-token>` for secret examples

## Skill Contract

For each published skill:

- directory exists under `skills/<skill-name>`
- `skills/<skill-name>/SKILL.md` is required
- relative links in `SKILL.md` must resolve
- `skills/manifest.yml` must be updated for add/remove/rename

## Required Validation Before Commit/PR

Run both commands from repo root:

```bash
./scripts/scan_public_risks.sh --path skills
./scripts/validate.sh
```

If changing sanitization pipeline, also verify staging flow:

```bash
./scripts/sanitize_public.sh --source ./skills --dest ./public-staging/skills --fail-on-hit
```

## CI Gate

`public-sanitize-validate` workflow is blocking.

CI must pass:

- public risk scanner
- skill contract validator

## Change Management

When renaming a skill:

1. Rename directory under `skills/`.
2. Update `skills/manifest.yml` name/path.
3. Update README examples and invocation names.
4. Update staged mirror (`public-staging/skills`) when applicable.
5. Re-run scanner and validator.

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
