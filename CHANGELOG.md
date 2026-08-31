# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `full-branch-audit` — Implicit whole-checkout review workflow that records
  the current Git state, launches a blind ephemeral read-only Codex reviewer,
  independently corroborates candidates, and verifies snapshot stability
  before reporting findings. Includes a managed global `AGENTS.md` snippet for
  consistent use across machines.

## [0.1.0] - 2026-04-27

Initial public release of the codex-skills repository.

### Added

#### Skills

- `claude-codex-dual-pass` — Reusable Claude Code + Codex dual-pass
  workflow with `cc <slash-command>` short-syntax aliases and
  AGENTS.md snippet helper scripts. Bare `cc` commands run with
  Claude bypass permissions by default; explicit permission
  modifiers remain available for read-only and edit-only runs.
- `commit-workflow` — Strict two-step Codex commit workflow: draft
  the message, get explicit user approval, then commit
  non-interactively.
- `drupal-sdc-figma-parity` — Drupal Single Directory Component
  Figma-to-code pixel-parity workflow using direct Figma MCP tools
  with screenshot-gated validation.
- `php-prebuild-quality` — Drupal 11 pre-build quality gates with
  dual-source validation (lint, PHPCS, PHPStan, PhpStorm CLI
  inspections, PHPUnit) in strict, changed-file, module-scoped,
  theme-scoped, or explicit-path modes.

#### Tooling

- Public sanitization pipeline (`scripts/sanitize_public.sh`) with
  Perl-based rewrite rules in `scripts/sanitize/rules.txt` and
  per-user/org/project overrides via ignored
  `scripts/sanitize/local.rules.txt` and `local.denylist.txt`.
- Public-risk scanner (`scripts/scan_public_risks.sh`) with ripgrep
  primary path and grep fallback for systems without ripgrep.
- Skill contract validator (`scripts/validate.sh`) enforcing
  directory layout, `SKILL.md` presence, link resolution, and
  `skills/manifest.yml` registration.
- Install/update one-command workflows (`scripts/install.sh`,
  `scripts/update.sh`) that deploy skills into `$CODEX_HOME` via
  symlink (default) or copy mode.
- CI gate workflow (`.github/workflows/public-sanitize-validate.yml`)
  running shellcheck, the public-risk scan, and skill validation on
  every push to `main` and all pull requests.
- `CLAUDE.md` providing repository guidance for Claude Code.

### Security

- CI workflow `public-sanitize-validate.yml` declares
  least-privilege `permissions: contents: read` at the workflow
  level (closes the initial code-scanning alert).
- All sanitizer and scanner patterns are self-safe — no literal
  private paths or obfuscated private literals are tracked in this
  repository; user-, org-, and project-specific rules live only in
  ignored `scripts/sanitize/local.*` files.

[Unreleased]: https://github.com/olegiv/codex-skills/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/olegiv/codex-skills/releases/tag/v0.1.0
