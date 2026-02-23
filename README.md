# Codex Skills (Public-Safe Repository)

This repository stores Codex skills for team sharing, with a mandatory
public-sanitization pipeline before publishing.

## Repository Layout

- `skills/` published skill directories
- `skills/manifest.yml` published skill inventory
- `scripts/` install, update, sanitize, scan, and validate tooling
- `.github/workflows/public-sanitize-validate.yml` CI gate
- `public-staging/` sanitized pre-publish staging output
- `AGENTS.md` contributor and automation operating contract

## Quick Start

Install all enabled skills into your Codex home:

```bash
./scripts/install.sh --skills all
```

Install selected skills only:

```bash
./scripts/install.sh --skills drupal-sdc-figma-parity
```

Update linked/copied skills and run validation:

```bash
./scripts/update.sh --skills all
```

Uninstall one skill from local Codex home:

```bash
rm -rf "$CODEX_HOME/skills/drupal-sdc-figma-parity"
```

## Public Sanitization Policy

The repo is publishable only if scanner and validator pass.

Forbidden in published content:

- absolute local paths (`/Users/...`, `/private/var/...`)
- internal identifiers (hostnames, project IDs, usernames)
- concrete token/secret/password values

Allowed:

- placeholder variables such as `$CODEX_HOME`, `<repo-root>`, `<username>`
- placeholder secrets such as `<your-token>`
- env var names such as `FIGMA_OAUTH_TOKEN`

## Placeholder Conventions

Use these placeholders in docs and scripts:

- `~/.codex` or `$CODEX_HOME` for Codex home
- `<repo-root>` for repository root paths
- `<project-id>` for project identifiers
- `<username>` for local usernames

## Sanitization Pipeline

Sanitize source skills and docs into staging:

```bash
./scripts/sanitize_public.sh \
  --source "$HOME/.codex/skills" \
  --source "<repo-root>/dev/AI/codex" \
  --dest "<repo-root>/dev/AI/codex-skills/public-staging/skills" \
  --fail-on-hit
```

Run scanner manually:

```bash
./scripts/scan_public_risks.sh --path public-staging/skills
```

Run validation manually:

```bash
./scripts/validate.sh
```

## Submodule Consumption Pattern

In a consumer project:

```bash
git submodule add <git-url> dev/AI/codex-skills
./dev/AI/codex-skills/scripts/install.sh --repo-root "$PWD/dev/AI/codex-skills" --skills all
```

## Add or Deprecate a Skill

1. Add/remove skill directory under `skills/`.
2. Update `skills/manifest.yml`.
3. Run `./scripts/scan_public_risks.sh --path skills`.
4. Run `./scripts/validate.sh`.
5. Open PR and ensure CI passes.

## Chat Invocation Example

```text
Use $drupal-sdc-figma-parity. Run workflow for this Figma node URL.
```

## Troubleshooting

- Skill not visible in Codex:
  - ensure it exists under `$CODEX_HOME/skills`
  - restart Codex or open a new session
- Stale symlink:
  - rerun `./scripts/install.sh --skills <name>`
- Scanner failures:
  - run `./scripts/scan_public_risks.sh --path <path>` and replace hits with placeholders

## License

This repository is licensed under **GNU General Public License v3.0**
(`GPL-3.0-or-later`).

See `LICENSE` for the full text.
