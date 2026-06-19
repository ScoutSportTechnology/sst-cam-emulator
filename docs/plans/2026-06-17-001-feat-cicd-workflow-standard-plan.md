---
title: "feat: Git + CI/CD workflow standard — sst-cam-emulator"
type: feat
status: active
date: 2026-06-17
origin: docs/brainstorms/2026-06-17-cicd-workflow-standard-requirements.md
---

# feat: Git + CI/CD workflow standard — sst-cam-emulator

## Summary

Establish the org-wide SST workflow standard in this **greenfield** repo from day one: the `feat/* → develop → release/X.Y.Z → main` branch model, the maturity ladder (alpha = build + automated tests in isolation, beta = faithful firmware stand-in in integration, stable = shipped), SemVer prerelease tags built before merge so `main` never runs a failable job, starting clean at the `0.1.0-alpha` line. Because the repo has **no source code and no chosen bridge language yet** (still at the brainstorm stage), the pipeline is set up structurally now, with the actual build/test invocation behind a thin `scripts/ci/` seam that the bridge implementation fills in later. No legacy to refactor — build it correctly the first time.

---

## Problem Frame

This repo has no CI/CD, no tags, no releases — a clean slate. The other three SST repos are adopting a shared branch/ladder/tag standard; the emulator must be set up to that standard from day one rather than refactored into it later. Its role is specific: the app validates its **alpha** against the emulator, so the emulator must be a trustworthy stand-in — which is exactly what its own **beta** rung proves. (see origin: docs/brainstorms/2026-06-17-cicd-workflow-standard-requirements.md)

---

## Requirements

- R1. Create a long-lived `develop` branch; default target for `feat/*`/`fix/*`.
- R2. Rulesets: `develop` requires PR + green checks; `main` requires PR + green required-status-checks + no direct push (admin/hotfix bypass only); `release/*` requires the release checks.
- R3. `main` runs **no failable build/publish job**.
- R4. Create `ci.yml`: build + automated tests on PRs into `develop` (and `release/*`).
- R5. On merge to `develop`, auto-build + tag `vX.Y.Z-alpha.N` and publish the alpha build.
- R6. On `release/X.Y.Z`, build + tag `vX.Y.Z-beta.N`; betas iterate on the branch.
- R7. Create the release-branch→main promotion: tag `vX.Y.Z` + publish the already-built artifact, no rebuild on `main`.
- R8. Adopt Conventional Commits as the automated bump source.
- R9. Start clean at the `0.1.0-alpha` line. Immediate target `0.1.0-beta.1` aligned with the app+firmware beta milestone. `1.0.0` = eventual first stable.
- R10. Create `CLAUDE.md`/`AGENTS.md`, `README` CI/CD sections matching the shared model used across the other three repos.

**Origin actors:** A1 Contributor, A2 Maintainer/admin, A3 CI, A4 sst-cam-app (primary consumer), A5 sst-cam-firmware (behavior reference).
**Origin flows:** F1 Feature→develop (alpha), F2 Cut release candidate (beta), F3 Promote to stable.
**Origin acceptance examples:** AE1 (R1,R4), AE2 (R5,R3), AE3 (R2,R3), AE4 (R7,R3).

---

## Scope Boundaries

- No external-tester cohorts; no nightly builds.
- No maintenance branches / backporting (latest-only-supported).
- Not cutting `1.0.0`.
- **The emulator's functional scope/behavior (the bridge daemon itself) is out of scope** — this plan is only the CI/CD + workflow setup. The bridge language/runtime selection and code remain the emulator's own future implementation plan.

### Deferred to Follow-Up Work

- Concrete build/test commands inside `scripts/ci/build.sh` + `scripts/ci/test.sh`: filled in by the bridge-implementation plan once the language/runtime is chosen. Until then they are honest no-op-with-clear-message placeholders (NOT skeletons of product code — CI plumbing). **AE1's build/test enforcement is therefore deferred** until the bridge fills the seam; in the interim the substantive gate is the `lint` job (shellcheck + actionlint, U2/U3), and alpha/beta/promote are **tag-only** (no asset) — green checks mean "plumbing + lint pass", not "build/tests enforced". This is called out so green is never misread as full enforcement.
- The exact artifact form (container image vs binary vs tarball) and whether it publishes to GHCR or as a Release asset: decided with the build tooling. Default assumption documented below: a Release asset, like the other repos.
- The fidelity-measurement definition for beta sign-off (recorded firmware fixture vs live device cross-check): defined with the conformance-vector work (shared vectors are this repo's owned surface per its CLAUDE.md).

---

## Context & Research

### Relevant Code and Patterns

- **No workflows exist** (`ls .github` is empty). Repo holds only `CLAUDE.md`, `README.md`, `docs/`.
- The pattern to mirror is the **sst-cam-app plan** authored in parallel (`sst-cam-app/docs/plans/2026-06-17-001-feat-cicd-workflow-standard-plan.md`) and the existing app/firmware/proto workflow files — same branch model, same `resolve-version.sh` approach, same "main never builds" artifact hand-off.
- `CLAUDE.md` states the repo is at brainstorm stage with no code and the bridge language deferred to planning — so the CI build/test step has nothing concrete to call yet.

### Institutional Learnings

- Bump tool across the org = **hand-rolled bash** (release-please removed; org blocks Actions-created PRs). Use the same. (memory: cicd-pipeline-plan)
- Default `GITHUB_TOKEN` only; "Release Tags" ruleset permits compliant tag creation, no bypass actor needed. (memory: cicd-pipeline-plan)
- Polyrepo + proto submodule decision: no shared-tooling repo, so this repo carries its own copy of `scripts/ci/resolve-version.sh`. (memory: monorepo-decision)

### External References

- SemVer 2.0 prerelease precedence `-alpha.N` < `-beta.N` < stable; `git tag --sort=-v:refname` orders correctly.

---

## Key Technical Decisions

- **Establish the standard fresh; do not wait for the bridge code.** The branch model, rulesets, version script, and four workflows are valuable independent of the bridge language. Set them up now so the bridge implementation lands *into* a correct pipeline.
- **Thin `scripts/ci/` indirection seam for build + test.** `ci.yml`/`alpha.yml`/`release-beta.yml` call `scripts/ci/build.sh` and `scripts/ci/test.sh`; today those echo a clear "build tooling not yet chosen — see bridge implementation plan" message and exit 0 (CI green, nothing to build yet). When the language lands, only those two scripts change — the pipeline stays. Rationale: satisfies R4–R7 structurally without inventing a build for nonexistent code.
- **Mirror the app plan's version math + artifact hand-off.** Same `scripts/ci/resolve-version.sh` (alpha/beta/stable modes), same "beta artifact → prerelease Release asset → promoted to stable Release by copy" so `main` never builds (R3/R7).
- **Default artifact = GitHub Release asset.** Consistent with app (APK) and firmware (binary). Re-evaluate only if the chosen build tooling makes a container image clearly better (deferred).
- **Greenfield = no version reset.** First `feat:` develop merge mints `v0.1.0-alpha.1` directly.

---

## Open Questions

### Resolved During Planning

- Bump tool? → Hand-rolled bash (org standard), shared `resolve-version.sh`.
- How to wire build/test when there's no code/language yet? → `scripts/ci/{build,test}.sh` indirection that no-ops cleanly until the bridge implementation fills them.
- Anything to reset? → No, greenfield; start at `0.1.0-alpha`.

### Deferred to Implementation

- Bridge language/runtime + concrete build/test commands — the emulator's own implementation plan.
- Artifact form + registry (Release asset assumed) — with build tooling.
- "Faithful stand-in" fidelity metric for beta sign-off — with the conformance-vector work.

---

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```
feat/* ──PR──► ci.yml (scripts/ci/build.sh + scripts/ci/test.sh) ──green+review──► develop
develop ──push──► alpha.yml ──► resolve-version.sh alpha ──► tag vX.Y.Z-alpha.N ──► build + publish alpha artifact (prerelease Release)
develop ──cut──► release/X.Y.Z ──push──► release-beta.yml ──► build + tag vX.Y.Z-beta.N (prerelease Release asset)
                                            │
                                  fidelity sign-off (app runs against it; behavior matches real firmware A5)
                                            │
release/X.Y.Z ──PR (beta green)──► main ──push──► promote.yml ──► tag vX.Y.Z ──► copy beta asset to stable Release  (NO build on main)
```

Until the bridge language is chosen, `scripts/ci/build.sh` and `scripts/ci/test.sh` print a clear "not yet implemented — see bridge implementation plan" and exit 0, so the pipeline is exercised end-to-end with green checks and the first real bridge PR drops straight into a working standard.

---

## Implementation Units

- U0. **Bootstrap the branch model (prerequisite — do before all other units)**

**Goal:** Create `develop` and make it the default branch so the new workflows and rulesets have a branch to key off. (Repo currently has only `main`, no tags, no workflows.)

**Requirements:** R1

**Dependencies:** None — first step; U3, U4, U7 depend on it.

**Files:**
- None (one-time `git` + `gh` operations; documented in `docs/ci/rulesets.md`)

**Approach:**
- Cut `develop` from `main` and push: `git switch -c develop main && git push -u origin develop`.
- Land the new workflow files on `develop` first.
- Open one throwaway PR into `develop` so `ci.yml` emits its check runs **once** — capture the exact names for U7's `required_status_checks` wiring.
- Flip the GitHub default branch: `gh api repos/:owner/:repo -X PATCH -f default_branch=develop`.
- Strict ordering: bootstrap → first CI run (capture names) → apply rulesets (U7 last). No version reset (greenfield).
- Note: the repo's existing commits are `docs:`-only, so until a real `feat:` lands the first alpha run correctly resolves `released=false` and mints nothing — that is expected, not a failure.

**Test scenarios:**
- Test expectation: none (one-time git/gh setup) — verification below.

**Verification:** `develop` exists, is the repo default, and a PR into it triggers `ci.yml`; rulesets applied only after the first run captured check names.

---

- U1. **Add `scripts/ci/resolve-version.sh` + tests (version math)**

**Goal:** One tested script the workflows call to compute the next alpha/beta/stable tag.

**Requirements:** R5, R6, R7, R8

**Dependencies:** None

**Files:**
- Create: `scripts/ci/resolve-version.sh`
- Create: `scripts/ci/resolve-version-test.sh` (or `.bats` — runner chosen at impl time)

**Approach:** Identical contract to the app plan's U1 — modes `alpha|beta|stable`, conventional-commit base bump from the latest stable tag, numeric prerelease counter via `git tag --sort=-v:refname`. With no tags + a `feat:` commit, `alpha` bumps from implicit `v0.0.0` → `v0.1.0-alpha.1` (restate the implicit-`v0.0.0` rule explicitly — this repo is in exactly the zero-tag state that previously tripped the "No releasable since v0.0.0" full-history-scan anomaly). Carry forward `release.yml`'s `IN_VERSION`/`IN_BUMP` override inputs so the first alpha can be seeded deterministically without relying on history-scan detection.

**Execution note:** Implement test-first — pure deterministic logic given a tag list.

**Patterns to follow:** `sst-cam-app/docs/plans/2026-06-17-001-feat-cicd-workflow-standard-plan.md` U1; the existing app `release.yml` bump bash.

**Test scenarios:**
- Happy path: no tags + `feat:` commit, mode `alpha` → `v0.1.0-alpha.1`. Covers AE2.
- Happy path: `[v0.1.0-alpha.1]` + another `feat:` merge, mode `alpha` → `v0.1.0-alpha.2`.
- Happy path: mode `beta v0.1.0` (no beta tags) → `v0.1.0-beta.1`; with `[v0.1.0-beta.1]` → `v0.1.0-beta.2`. Covers F2.
- Happy path: mode `stable v0.1.0` → `v0.1.0`.
- Edge case: numeric precedence — `-alpha.10` sorts after `-alpha.9` → next is `.11`.
- Edge case: docs/chore-only since last stable, mode `alpha` → `released=false` (skip).
- Error path: invalid mode/base → non-zero exit with message.
- Happy path: forced `IN_VERSION`/`IN_BUMP` override → emits exactly that version regardless of tag/commit scan (deterministic first-alpha seed).
- Edge case: zero tags AND no `feat:` in range (current `docs:`-only history) → `released=false`, mints nothing (expected first-run behavior).

**Verification:** Test suite green; correct tag emitted for each fixture, including the zero-baseline and forced-seed cases.

---

- U2. **Add the `scripts/ci/build.sh` + `scripts/ci/test.sh` seam**

**Goal:** A single indirection point for build + test so workflows are stable while the bridge language is undecided — **without** the gate being vacuous in the meantime.

**Requirements:** R4

**Dependencies:** None

**Files:**
- Create: `scripts/ci/build.sh`
- Create: `scripts/ci/test.sh`

**Approach:** `build.sh`/`test.sh` print a clear "build tooling not yet chosen — implemented by the bridge implementation plan" notice and exit 0 (intentional CI plumbing, not a product skeleton). **But a no-op that always exits 0 makes the required checks vacuous** — they can never fail, so AE1 ("build + tests green before merge") is satisfied only in *form*, not substance, until the bridge lands. To keep "green" meaningful from day one, the seam ships alongside **a genuinely-failable check now**: a `lint` job running `shellcheck scripts/ci/*.sh` + `actionlint` on the workflow YAML. That gate catches real defects (broken scripts/workflows) immediately. When the bridge language lands, `build.sh`/`test.sh` get the real commands and the gate becomes fully substantive — only those two scripts change.

**Patterns to follow:** Shell scripts under `scripts/ci/`.

**Test scenarios:**
- Happy path: a malformed `scripts/ci/*.sh` or workflow YAML → the `lint` job (shellcheck/actionlint) fails the PR (proves the gate is non-vacuous before the bridge exists).
- `build.sh`/`test.sh`: exit 0 + emit the explanatory notice (no-op until the bridge lands).

**Verification:** `shellcheck`/`actionlint` fail on a deliberately-broken script/workflow; `build.sh`/`test.sh` exit 0 with the notice. AE1's *build/test* enforcement is explicitly deferred until the bridge fills the seam (see Scope Boundaries) — the lint gate is the substantive check in the interim.

---

- U3. **Create `ci.yml` — PR checks on `develop`/`release/*`**

**Goal:** PRs into `develop` and `release/*` run build + automated tests.

**Requirements:** R1, R4, R3

**Dependencies:** U0, U2

**Files:**
- Create: `.github/workflows/ci.yml`

**Approach:** `on.pull_request.branches: [develop, release/**]`; jobs `lint` (shellcheck `scripts/ci/*.sh` + actionlint — the substantive gate today), `build` (calls `scripts/ci/build.sh`), `test` (calls `scripts/ci/test.sh`). All three become required checks. Until the bridge lands, `build`/`test` are green-by-no-op and `lint` is the only failable gate — documented so green is not mistaken for full enforcement (see U2 + Scope Boundaries).

**Test scenarios:**
- Happy path: PR `feat/x → develop` → build + test jobs run and gate merge. Covers AE1.
- Happy path: PR into `release/0.1.0` → same checks run.
- Edge case: PR into `main` does not trigger `ci.yml`.

**Verification:** `develop`/`release/*` PRs show the required checks; `main` PRs do not run them.

---

- U4. **Create `alpha.yml` — tag + publish alpha on push to `develop`**

**Goal:** Merge to `develop` auto-tags `vX.Y.Z-alpha.N` + publishes the alpha artifact.

**Requirements:** R5, R3, R8

**Dependencies:** U0, U1, U2

**Files:**
- Create: `.github/workflows/alpha.yml`

**Approach:** `on.push.branches: [develop]` + `workflow_dispatch`. Call `resolve-version.sh alpha`; if `released=true`, run `scripts/ci/build.sh`, `gh release create vX.Y.Z-alpha.N --prerelease --generate-notes`, then **upload only if an artifact exists**. During the no-op-seam window `build.sh` emits nothing, so the alpha is **tag-only** (prerelease Release, no asset) — the upload step is conditional on a produced-artifact manifest, not unconditional (an unconditional `gh release upload <nonexistent>` would fail the run). When the bridge fills `build.sh`, the same step uploads the real artifact with no workflow change. `permissions: contents: write`.

**Test scenarios:**
- Happy path: `feat:` merge to `develop` → `v0.1.0-alpha.1` prerelease created. Covers AE2.
- Edge case: docs/chore-only merge → skip, green.
- Edge case: second `feat:` merge → `v0.1.0-alpha.2`.
- Integration: the build runs here, not on main (R3).

**Verification:** A `feat:` merge yields a `-alpha.N` prerelease; non-releasable merges produce none.

---

- U5. **Create `release-beta.yml` — build + tag + publish beta on `release/*`**

**Goal:** Pushes to `release/X.Y.Z` build the artifact, tag `vX.Y.Z-beta.N`, publish it as a prerelease Release asset (what `main` later promotes).

**Requirements:** R6, R3

**Dependencies:** U0, U1, U2

**Files:**
- Create: `.github/workflows/release-beta.yml`

**Approach:** `on.push.branches: [release/**]` + `workflow_dispatch`. Base `X.Y.Z` from branch name; `resolve-version.sh beta X.Y.Z`; run `scripts/ci/build.sh`; `gh release create vX.Y.Z-beta.N --prerelease`; **upload the asset only if `build.sh` produced one** (tag-only during the no-op-seam window — same conditional as U4).

**Test scenarios:**
- Happy path (post-bridge): push to `release/0.1.0` → `v0.1.0-beta.1` with the artifact. Covers F2.
- Happy path (seam window): push to `release/0.1.0` → `v0.1.0-beta.1` tag-only (no asset), green.
- Happy path: another push → `v0.1.0-beta.2`.
- Edge case: branch name not matching `release/X.Y.Z` → fail fast.

**Verification:** A `release/0.1.0` push produces a `v0.1.0-beta.N` prerelease (carrying the artifact post-bridge; tag-only during the seam window).

---

- U6. **Create `promote.yml` — tag stable + copy beta artifact on push to `main` (no build)**

**Goal:** `release/X.Y.Z → main` tags `vX.Y.Z` and publishes the already-built beta artifact by copying — zero build on `main`.

**Requirements:** R7, R3

**Dependencies:** U0, U5

**Files:**
- Create: `.github/workflows/promote.yml`

**Approach:** `on.push.branches: [main]` + `workflow_dispatch`. Derive `X.Y.Z` from the merged `release/X.Y.Z` branch name; select the source beta tag `git tag -l "vX.Y.Z-beta.*" --sort=-v:refname | head -1`; `resolve-version.sh stable X.Y.Z`; `gh release create vX.Y.Z --generate-notes`. Then, **if the beta Release carries an asset**, download + re-upload it (renamed `-beta.N`→stable, bytes preserved) to the stable Release; **during the no-op-seam window the beta is tag-only, so promote is tag-only too** (the "no asset" case is the documented-skip path, NOT the fail-fast path — fail-fast applies only to a missing *beta tag*, not a missing asset). **No build step in this workflow** (the R3/AE4 guarantee).

**Test scenarios:**
- Happy path (post-bridge): merge `release/0.1.0 → main` → `v0.1.0` tagged, beta artifact appears on the stable Release. Covers AE4.
- Happy path (seam window): merge `release/0.1.0 → main` → `v0.1.0` tagged, no asset (beta had none), green.
- Edge case: no matching beta *tag* for the version → fail fast (never silently rebuild).
- Edge case: workflow has no build step — assert by inspection. Covers R3.

**Verification:** `main` has zero failable build jobs; the stable Release reuses the beta artifact when one exists, else is tag-only.

---

- U7. **Branch + tag rulesets for `develop`, `main`, `release/*`**

**Goal:** Enforce the branch model and required checks via GitHub rulesets. (Default-branch flip is U0.)

**Requirements:** R1, R2, R3

**Dependencies:** U0, U3, U4, U5, U6

**Files:**
- Create: `docs/ci/rulesets.md` (intent + the `gh api` commands/JSON)

**Approach:** `develop`: PR + green required checks (`lint`, `build`, `test`). `main`: PR + green required checks + block direct push/force/delete, admin/hotfix bypass. The `main` PR's required check is the release-branch head SHA's already-green `ci.yml` runs reused (the head SHA is the PR head) — no re-run; verify GitHub surfaces it, else add a lightweight no-build assertion gate. `release/*`: require the beta checks. Create an immutable tag ruleset for `v*` (this repo has none yet). Wire `required_status_checks` only after U0/U3–U6 run once and exact names are known.

**Execution note:** Capture required-check names from a real run before wiring (prior-CI name-mismatch trap).

**Test scenarios:**
- Test expectation: none (GitHub configuration) — verification operational below.

**Verification:** Direct push to `main` rejected; a `release/* → main` PR with red checks blocked (AE3); `develop` is the default branch.

---

- U8. **Docs: create CI/CD sections in `CLAUDE.md`, `AGENTS.md`, `README`**

**Goal:** Documentation describes the shared model, matching the other three repos.

**Requirements:** R10

**Dependencies:** U0, U3, U4, U5, U6, U7

**Files:**
- Modify: `CLAUDE.md`
- Create/Modify: `AGENTS.md`
- Modify: `README.md`

**Approach:** Add the four-workflow model, the maturity ladder (alpha = build+tests in isolation; beta = fidelity as a firmware stand-in; stable = shipped), the `vX.Y.Z[-alpha.N|-beta.N]` scheme, the branch flow, and the two non-negotiables. Note the `scripts/ci/` seam so future bridge work knows where the build/test commands go.

**Test scenarios:**
- Test expectation: none (documentation) — verification below.

**Verification:** Docs describe four workflows + the ladder + tag scheme, structurally matching the app/firmware/proto repos, and point at the `scripts/ci/` seam.

---

## System-Wide Impact

- **Interaction graph:** New workflows key off `develop`/`release/**`/`main`. The app (A4) runs its alpha against this repo's tagged builds; firmware (A5) is the fidelity reference; proto is the contract the bridge speaks.
- **Error propagation:** Build/test failures land on PRs and `develop`/`release/*`, never on `main`.
- **State lifecycle risks:** The `scripts/ci/` no-op seam must not be mistaken for a finished build — documented explicitly as deferred plumbing.
- **API surface parity:** Same branch/ladder/tag model as app, firmware, proto.
- **Unchanged invariants:** No product/bridge code is created by this plan; only pipeline, rulesets, scripts, and docs.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Build/test seam mistaken for a real build → false confidence; vacuous always-green checks | A genuinely-failable `lint` job (shellcheck + actionlint) ships now so the gate isn't vacuous; AE1 build/test enforcement explicitly marked deferred (Scope Boundaries). |
| `develop` not created → `develop`/`release/*` triggers reference a missing branch | U0 bootstraps `develop` + default flip before any workflow. |
| Artifact upload/download of a nonexistent asset during the seam window | alpha/beta upload conditional on a produced artifact; promote treats no-asset as the documented-skip (tag-only) path, fail-fast only on a missing beta *tag* (U4–U6). |
| Required-status-check names wired before the check runs once | Wire after U3–U6 run once (prior-CI learning). |
| Prerelease counter math wrong (lexical vs numeric) | U1 tests assert numeric precedence. |
| `promote.yml` accidentally builds on main | Structural: no build step; asserted by inspection. |
| Cross-repo drift (emulator ladder ≠ app/firmware/proto) | Plans authored together; same version contract documented in each. |
| Bridge language choice later forces a different artifact/registry | Only `scripts/ci/{build,test}.sh` + the upload step change; pipeline structure is artifact-agnostic. |

---

## Documentation / Operational Notes

- One operational runbook: ruleset application (U7) via `gh`. No version reset (greenfield).
- `0.1.0-beta.1` aligns with the app+firmware beta milestone — coordinate timing.

---

## Sources & References

- **Origin document:** [docs/brainstorms/2026-06-17-cicd-workflow-standard-requirements.md](docs/brainstorms/2026-06-17-cicd-workflow-standard-requirements.md)
- Sibling plan (pattern source): `sst-cam-app/docs/plans/2026-06-17-001-feat-cicd-workflow-standard-plan.md`
- Repo state: empty `.github/`, `CLAUDE.md` (brainstorm-stage, bridge language deferred)
- Prior CI/CD work: memory `cicd-pipeline-plan`, `monorepo-decision`
