# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A public-safe repository of reusable Codex skills (AI agent instruction sets). Includes a mandatory sanitization pipeline to prevent private data leaks (local paths, hostnames, secrets) before publishing. Licensed GPL-3.0-or-later.

## Common Commands

```bash
# Validate skill contracts (directory, SKILL.md, links, manifest)
./scripts/validate.sh

# Scan for private data leaks in skill content
./scripts/scan_public_risks.sh --path skills

# Sanitize skills into public-staging
./scripts/sanitize_public.sh --source ./skills --dest ./public-staging/skills --fail-on-hit

# Install all enabled skills to local Codex home
./scripts/install.sh --skills all

# Install a single skill
./scripts/install.sh --skills drupal-sdc-figma-parity

# Update installed skills and re-validate
./scripts/update.sh --skills all

# Lint all shell scripts
shellcheck scripts/*.sh scripts/lib/*.sh
```

**Before every commit/PR**, run both:
```bash
./scripts/scan_public_risks.sh --path skills
./scripts/validate.sh
```

## Architecture

### Flow

`manifest.yml` → `install.sh` (deploy to `$CODEX_HOME`) → `validate.sh` (contract check) → `sanitize_public.sh` (strip private data) → `scan_public_risks.sh` (verify clean) → CI gate

### Key Components

- **`skills/manifest.yml`** — Central registry of all skills. Pure-bash parser in `scripts/lib/common.sh` reads it as pipe-delimited records. Must be updated for any skill add/remove/rename.
- **`skills/<name>/SKILL.md`** — Required entry point for each skill. May have `references/`, `scripts/`, `agents/` subdirectories.
- **`scripts/lib/common.sh`** — Shared shell library (`log`, `err`, `die`, `trim`, `strip_quotes`, `normalize_bool`, `resolve_repo_root`, `parse_manifest`).
- **`scripts/sanitize/rules.txt`** — Perl substitution rules that replace private data with placeholders.
- **`public-staging/`** — Output directory for sanitized content. Contents are gitignored except `.gitkeep` files.

### CI Gate

`.github/workflows/public-sanitize-validate.yml` runs on every push to `main` and all PRs:
1. shellcheck on all scripts
2. public risk scan on `skills/`
3. skill contract validation

## Public-Safe Rules

All content must use placeholders instead of real values:
- `$CODEX_HOME` or `~/.codex` for Codex home paths
- `<repo-root>` for repository root
- `<project-id>`, `<username>`, `<your-token>` for identifiers and secrets
- `example.local` for internal hostnames

Never include: absolute local paths, internal hostnames/project IDs, concrete secrets/tokens/passwords.

## Skill Contract

Each published skill must:
1. Have a directory under `skills/<skill-name>/`
2. Contain `skills/<skill-name>/SKILL.md`
3. Have all relative links in SKILL.md resolve correctly (no broken links, no absolute links)
4. Be registered in `skills/manifest.yml`

## Renaming a Skill

1. Rename directory under `skills/`
2. Update `skills/manifest.yml` name and path
3. Update README examples
4. Update `public-staging/skills/` mirror if applicable
5. Re-run scanner and validator

## Language/Tool Notes

- Primary language is **Bash** (all scripts). Scripts must pass **shellcheck**.
- Sanitization uses **Perl** regex (via `perl -pe`) with rules from `sanitize/rules.txt`.
- Risk scanning uses **ripgrep** with a **grep** fallback.
- `parse_manifest()` in `common.sh` is a pure-bash YAML parser — it only handles the flat structure of `manifest.yml`, not arbitrary YAML.
