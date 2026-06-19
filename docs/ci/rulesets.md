# Branch + tag rulesets — sst-cam-emulator

> **APPLIED 2026-06-18.** These rulesets are now live on the repo: **Release
> Tags**, **develop**, **main**, and **release-branches**, with **OrgAdmin
> bypass**. `develop` requires the three checks `Lint (shellcheck + actionlint)`
> / `Build` / `Test`; `main`'s required checks are **deferred** (see the open
> caveat below). The commands below are retained as the reference/runbook for how
> they were applied and how to reapply or audit them. The PR gate now lives
> inside `release-alpha.yml` (develop) and `release-beta.yml` (release/**), not a
> standalone `ci.yml`.

**Maintainer runbook.** This file documents the intent and the exact `gh api`
calls to apply the GitHub rulesets that enforce the SST Cam workflow standard in
this repo. It is **not** executed by CI — a maintainer/admin runs these once,
after the bootstrap (U0) and after the workflows have produced their check runs
once so the required-status-check names are known.

This repo was **greenfield** when this runbook was written: no rulesets and no
tags yet, so every ruleset below is created fresh. There is no version reset.

---

## Ordering (strict)

1. **Bootstrap (U0)** — cut `develop` from `main`, push it, flip the GitHub
   default branch to `develop`:
   ```bash
   git switch -c develop main && git push -u origin develop
   gh api repos/:owner/:repo -X PATCH -f default_branch=develop
   ```
2. **First CI run** — open one throwaway PR into `develop` so `release-alpha.yml`
   emits its three PR-gate check runs once. Capture the **exact** check-run names
   from that run — they are what `required_status_checks.contexts` must match.
   Based on the check-job names in `.github/workflows/release-alpha.yml` (and the
   identical ones in `release-beta.yml`) they are:
   - `Lint (shellcheck + actionlint)`
   - `Build`
   - `Test`

   Verify against the actual run before wiring — a name mismatch silently makes a
   "required" check non-blocking.
3. **Apply rulesets (this doc)** — only after steps 1–2.

---

## `develop` — integration branch

Intent: PR required, all three CI checks green before merge. Default target for
`feat/*` and `fix/*`.

```bash
gh api repos/:owner/:repo/rulesets -X POST --input - <<'JSON'
{
  "name": "develop protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/heads/develop"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [
          { "context": "Lint (shellcheck + actionlint)" },
          { "context": "Build" },
          { "context": "Test" }
        ]
      }
    }
  ]
}
JSON
```

---

## `main` — stable branch (never builds)

Intent: PR required, the same three CI checks green, no direct push / force-push /
delete. Admin/hotfix bypass only. `main` itself runs **no failable build job** —
`release.yml` only tags + copies the already-built beta asset.

> **As applied (2026-06-18):** the `main` ruleset is live with PR + bypass, but
> its **required status checks are deferred** (see the open caveat below) — they
> are not yet wired as blocking on `main`. The `develop` and `release/**`
> required checks are live.

```bash
gh api repos/:owner/:repo/rulesets -X POST --input - <<'JSON'
{
  "name": "main protection",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    { "actor_type": "RepositoryRole", "actor_id": 5, "bypass_mode": "always" }
  ],
  "conditions": { "ref_name": { "include": ["refs/heads/main"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [
          { "context": "Lint (shellcheck + actionlint)" },
          { "context": "Build" },
          { "context": "Test" }
        ]
      }
    }
  ]
}
JSON
```

`actor_id: 5` is the built-in **Admin** repository role (bypass for hotfix).
Adjust to your org's role IDs (`gh api repos/:owner/:repo/rulesets/rule-suites`
or the org roles API to confirm).

### Open caveat — reusing the release-branch checks on the `main` PR

A `release/X.Y.Z → main` PR's head SHA is the release-branch head, which already
ran the gate checks green (PRs into `release/*` trigger `release-beta.yml`'s
`pull_request` checks — see U3). The intent is for GitHub to **surface those
already-green check runs on the main PR head SHA** rather than re-running anything.

**This is unverified and left open.** GitHub does not always surface a prior
commit's check runs against a new PR context reliably. If the main PR shows the
required checks as missing/pending despite the release branch being green:

- **Option A (preferred):** confirm GitHub reuses the head-SHA check runs once a
  real release PR exists, then keep this config as-is.
- **Option B (fallback):** add a lightweight `pull_request.branches: [main]`
  no-build assertion job (e.g. to `release.yml` or a dedicated workflow) that
  re-emits the three check contexts on the main PR head without building —
  preserving the "main never builds" guarantee while giving the ruleset a check
  to gate on.

> This is the reason `main`'s required checks are **deferred** in the live config
> (noted under the `main` section above) — they will be wired once the first
> release PR settles which option holds.

Do not resolve this by adding a build step to the main path. Flagged here for the
maintainer to settle when the first release PR is cut.

---

## `release/*` — release-candidate branches

Intent: PR required (when merging fixes into a release branch) and the same CI
checks; pushes to `release/*` also trigger `release-beta.yml` to mint betas.

```bash
gh api repos/:owner/:repo/rulesets -X POST --input - <<'JSON'
{
  "name": "release branch protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/heads/release/**"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [
          { "context": "Lint (shellcheck + actionlint)" },
          { "context": "Build" },
          { "context": "Test" }
        ]
      }
    }
  ]
}
JSON
```

---

## `v*` tags — immutable SemVer (new — greenfield has none)

Intent: published version tags (`vX.Y.Z`, `vX.Y.Z-alpha.N`, `vX.Y.Z-beta.N`) are
immutable — no delete, no move/force-push. The default `GITHUB_TOKEN` used by the
workflows can still *create* compliant tags; only deletion/modification is blocked.

```bash
gh api repos/:owner/:repo/rulesets -X POST --input - <<'JSON'
{
  "name": "v* immutable tags",
  "target": "tag",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" }
  ]
}
JSON
```

---

## Verification (operational)

- Direct push to `main` is rejected.
- A `release/* → main` PR with red required checks cannot merge (AE3).
- `develop` is the repo default branch.
- Attempting to delete or move a `v*` tag is rejected.

## Seam-window note

During the seam window the `Build`/`Test` checks are green-by-no-op (the bridge
language is not chosen yet — see `scripts/ci/build.sh`/`test.sh`). The substantive
failable required check is `Lint`. Keep all three wired as required so they become
fully enforcing automatically once the bridge fills the seam — no ruleset change
needed at that point.
