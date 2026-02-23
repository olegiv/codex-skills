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

- absolute local machine paths (`/Users/...`, `/private/var/...`)
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
