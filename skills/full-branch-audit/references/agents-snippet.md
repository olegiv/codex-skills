<!-- codex-skill:full-branch-audit:start -->
### Independent Full-Branch Audits

When the user asks to audit or review the current branch, check again for remaining findings,
perform a pre-commit full review, or match GitHub Codex review quality, invoke
`$full-branch-audit`.

Audit the exact current checkout: committed HEAD plus staged, unstaged, and untracked files. A base
branch is context only, never the review scope. Use a fresh, blind, ephemeral read-only Codex process
through the skill's clean-home launcher, then independently corroborate every candidate against the
current files. Recheck snapshot stability before reporting. Never substitute a diff-only,
same-context, or recursively nested review.
<!-- codex-skill:full-branch-audit:end -->
