---
name: full-branch-audit
description: Perform an independent, read-only audit of the entire current Git checkout—committed HEAD plus staged, unstaged, and untracked files—when the user asks to scan the current branch, check again for findings, audit before commit, or match GitHub Codex review quality. Do not use when the user explicitly limits the review to one PR diff or commit.
metadata:
  short-description: Independent whole-branch code validation
---

# Full Branch Audit

Review the exact repository state visible to the user, not merely its diff from a base branch. Use a
fresh Codex process to break editing-context bias, then independently corroborate every candidate
before reporting it.

## Non-negotiable contract

- Scope the complete current checkout: committed `HEAD`, staged changes, unstaged changes, and
  untracked files. Treat a base branch only as history and attribution context.
- Read every applicable `AGENTS.md` and repository-specific validation instruction before choosing
  checks.
- Remain read-only unless the user separately asks for fixes. Do not edit, stage, commit, push, post
  review comments, or mutate external state during the audit.
- Give the isolated reviewer no earlier findings, suspected defects, or desired answer.
- Never launch an isolated reviewer from inside an isolated reviewer. If
  `CODEX_FULL_BRANCH_AUDIT_CHILD=1` is present, perform the assigned review directly and do not
  invoke this skill, another Codex process, a subagent, or any delegation mechanism.
- Continue through the whole repository after finding the first defect. Passing tests and scanners
  do not prove semantic or operational correctness.
- Report only concrete, reachable defects with a user-visible, security, data-integrity, deployment,
  or maintainability consequence worth fixing. Reject style preferences and speculative concerns.
- Do not claim the repository is clean if a required pass failed, was interrupted, or observed a
  changing snapshot.

## Workflow

### 1. Record the current-tree snapshot

Run `scripts/snapshot_current_tree.sh <repo>` and retain its output outside the repository. It binds
the audit to `HEAD`, tracked changes, status, and untracked content without changing the worktree.
Also record `git status --short --branch` for the final report.

Ignored build output, caches, credentials, and dependency directories are outside normal review
scope unless repository instructions or the user's request explicitly include them.

### 2. Inspect repository contracts and choose checks

Map the repository before reviewing: languages, entry points, CI workflows, deployment scripts,
migrations, persistence, privilege boundaries, generated code, and production/runtime surfaces.
Run applicable project gates and language-specific security checks. Prefer the repository's own
commands. Add focused race, vulnerability, static-analysis, migration, shell, or platform checks
when the code makes them relevant.

Tests may populate external caches or temporary directories, but they must not alter tracked or
untracked source state. Never run deployment, destructive, credentialed, or production actions as
part of an audit.

### 3. Run a blind isolated reviewer

Read [references/reviewer-prompt.md](references/reviewer-prompt.md) and pass it unchanged to a fresh
local Codex process with the bundled launcher:

```sh
<skill-dir>/scripts/run_isolated_reviewer.sh <repo>
```

The launcher creates a mode-0700 temporary `CODEX_HOME`, exposes authentication only, ignores the
normal user configuration, and supplies a developer-level recursion guard. It does not expose user
skills, plugins, global `AGENTS.md`, rules, memories, or prior sessions. It also uses ephemeral,
read-only, never-approve execution and removes the temporary home on exit.

Do not replace the launcher with a direct `codex exec` call using the normal `CODEX_HOME`: the
isolated reviewer would inherit this skill and could recursively launch another reviewer. Use the
strongest locally available reviewer configuration appropriate to the repository. Optional
`CODEX_REVIEW_MODEL` and `CODEX_REVIEW_REASONING` environment variables select a model and reasoning
effort without copying the normal user configuration.

Do not reuse the editing conversation, an earlier review session, or an output-seeded follow-up. If
the local Codex executable or usable authentication is unavailable, report that independent review
is blocked; do not present an in-context self-review as equivalent.

For broad, security-sensitive, or release-critical repositories, run a second fresh challenger with
the same full-tree scope and a platform/security/lifecycle emphasis. Keep it blind to the first
reviewer's output.

### 4. Corroborate candidates independently

The primary agent must verify each candidate against the current files:

- trace the reachable call, data, privilege, or state-transition path;
- identify the violated invariant and concrete impact;
- check callers, tests, schemas, error paths, cleanup, retries, cancellation, and platform behavior;
- reproduce safely in a temporary location when a deterministic proof materially improves confidence;
- reject duplicates, unreachable scenarios, intentional behavior, and claims based only on missing
  tests or scanner output.

Whole-tree findings may predate the current branch. Mark attribution when known, but do not omit a
confirmed defect merely because it is not diff-introduced.

### 5. Verify snapshot stability

Run `scripts/snapshot_current_tree.sh <repo>` again. If any value differs, invalidate the results and
restart against the new state. Never merge findings from different snapshots.

### 6. Deliver the review

Lead with the outcome and findings ordered P0 through P3. For each finding provide an exact path and
line, reachable trigger, root cause, production impact, and concise remediation direction. Use
inline code-review comments for the most important line-specific findings when the client supports
them.

Then report:

- the recorded `HEAD` and whether staged, unstaged, or untracked files were included;
- verification commands and their outcomes;
- rejected or residual risks separately from actionable findings;
- confirmation that no files, commits, pushes, or external review state were changed.

If no defect survives corroboration, say `No confirmed findings on the recorded current-tree
snapshot`; do not promise that no defect exists.

## Global installation

To make this workflow the default for branch-audit requests on a machine, install the skill under
`$CODEX_HOME/skills` and apply its managed global instruction block:

```sh
<skill-dir>/scripts/apply_agents_snippet.sh
```

The helper edits only its marked block in `$CODEX_HOME/AGENTS.md`. Run it again after updating the
skill to refresh the block.
