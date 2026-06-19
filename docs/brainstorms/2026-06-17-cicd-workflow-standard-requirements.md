---
date: 2026-06-17
topic: cicd-workflow-standard
---

# Git + CI/CD Workflow Standard — sst-cam-emulator

## Summary

**Establish** (this repo is greenfield — no workflows, tags, or releases yet) the org-wide SST workflow standard from scratch: `feat/* → develop → release/X.Y.Z → main`, a maturity ladder (alpha = builds + automated tests in isolation, beta = validated as a faithful firmware stand-in in integration, stable = shipped), SemVer tags built before merge so `main` never runs a failable job, starting at the `0.1.0-alpha` line. The emulator is the bridge that lets the app's alpha testing run **without real hardware**, so its fidelity to real firmware is the thing beta proves.

---

## Problem Frame

This repo has no CI/CD, no tags, no releases — a clean slate. The other three SST repos are adopting a shared branch/ladder/tag standard; the emulator must be set up *to that standard from day one* rather than refactored into it later. It also has a specific role: the app validates its **alpha** against the emulator (mock + emulated firmware data), so the emulator must be a trustworthy stand-in — which is exactly what its own **beta** rung must establish.

---

## Actors

- A1. **Contributor** — `feat/*`/`fix/*` branches, PRs into `develop`.
- A2. **Maintainer/admin** (you) — cuts release branches, signs off fidelity, merges the release gate, manages rulesets/tags.
- A3. **CI** — checks + builds on PRs; tagged emulator/bridge artifacts.
- A4. **sst-cam-app** — the primary consumer; runs its alpha testing against this emulator.
- A5. **sst-cam-firmware** — the behavior reference the emulator must faithfully mirror.

---

## The Workflow Standard (shared across all four SST repos)

**Branches**
- `feat/*`, `fix/*` — off `develop`. Free: no CI/CD while working.
- `develop` — always-green integration trunk (enforced by the PR gate).
- `release/X.Y.Z` — short-lived, cut from `develop`, deleted after merge to `main`.
- `main` — final released code only; nothing builds here, it promotes the signed-off artifact.
- `hotfix/*` — off the `main` tag for urgent fixes.

**Maturity ladder (by test fidelity)**
- **alpha** — validated in *isolation, automatically*.
- **beta** — validated in *integration, by hand* (maintainer is the tester).
- **stable** — beta signed off and shipped.

**Versions & tags (SemVer 2.0)**
- Semantic version `X.Y.Z[-alpha.N|-beta.N]` (no `v`); git tag = version with a `v` prefix (tag-name convention only).
- `vX.Y.Z-alpha.N` on `develop` (auto) → `vX.Y.Z-beta.N` on `release/X.Y.Z` (gated/manual) → `vX.Y.Z` on `main` (stable). Order: `-alpha.N` < `-beta.N` < stable.
- Pre-1.0 (`0.MINOR.PATCH`): minor = feature, patch = fix, no stability guarantee. `1.0.0` = first stable. Post-1.0: **major = breaks the proto/wire contract it emulates or its own consumer interface**, minor = backward-compatible capability, patch = fix.

**The two non-negotiable rules**
- **Build-in-PR / tag-on-merge.** The failable build runs before a merge; a merge only tags/promotes already-validated code. `main` never builds.
- **`main`'s checks are gates, not re-runs** — promotion requires the release branch's checks green; they ran upstream.

**Flow**
```
feat/* ─PR: build + automated tests─► develop ─auto─► tag vX.Y.Z-alpha.N (alpha emulator build)
develop ─cut─► release/X.Y.Z ─build + tag vX.Y.Z-beta.N─► fidelity sign-off (app runs against it; behavior matches real firmware)
release/X.Y.Z ─PR (beta checks green)─► main ─► tag vX.Y.Z + publish ; delete release branch ; merge back to develop
hotfix: off main tag → fix → vX.Y.(Z+1) → main → back to develop
```

**Release trigger** — automated bump from Conventional Commits + one human gate. Beta→stable sign-off manual for now.

---

## This repo's specifics

- **Artifact:** the emulator / bridge build (emulated firmware that speaks the proto contract over the same wire as a real device).
- **alpha** = builds + its own automated tests pass, in isolation (the emulator runs and emits emulated data). Automated.
- **beta** = validated as a **faithful firmware stand-in** in integration: the app runs against the emulator and the behavior matches the real firmware (same proto contract, same observable responses). This fidelity is what lets the app trust its alpha results. Manual maintainer sign-off, ideally cross-checked against a real device.
- **Greenfield:** there is nothing to reset — set up `ci.yml`, the `develop` branch, rulesets, and tagging fresh, to the standard.

---

## Key Flows

- F1. **Feature → develop (alpha).** PR `feat/x → develop` → CI build + automated tests → green + review → merge → tag `vX.Y.Z-alpha.N` + publish alpha build. Covers: R1, R4, R5.
- F2. **Cut release candidate (beta).** Maintainer cuts `release/X.Y.Z`; CI builds + tags `vX.Y.Z-beta.N`; app runs against it and behavior is checked against the real firmware; sign-off on fidelity. Covers: R3, R6.
- F3. **Promote to stable.** PR `release/X.Y.Z → main` (beta checks green) → tag `vX.Y.Z` + publish; delete release branch; merge back to develop. Covers: R3, R7.

---

## Requirements

**Branch model & protection (establish from scratch)**
- R1. Create a long-lived `develop` branch; default target for `feat/*`/`fix/*`.
- R2. Rulesets: `develop` requires PR + green checks; `main` requires PR + green required-status-checks + no direct push (admin/hotfix bypass only); `release/*` requires the release checks.
- R3. `main` runs **no failable build/publish job**.

**CI/CD pipelines (create new)**
- R4. Create `ci.yml`: build + automated tests on PRs into `develop` (and `release/*`).
- R5. On merge to `develop`, auto-build + tag `vX.Y.Z-alpha.N` and publish the alpha build (build-in-PR).
- R6. On `release/X.Y.Z`, build + tag `vX.Y.Z-beta.N`; betas iterate on the branch.
- R7. Create the release-branch→main promotion: tag `vX.Y.Z` + publish the already-built artifact, no rebuild on `main`. (No legacy `release.yml` to replace — build it correctly the first time.)
- R8. Adopt Conventional Commits as the automated bump source.

**Versioning**
- R9. Start clean at the `0.1.0-alpha` line (nothing to reset). Immediate target `0.1.0-beta.1` aligned with the app+firmware beta milestone. `1.0.0` = eventual first stable.

**Documentation**
- R10. Create/update `CLAUDE.md`/`AGENTS.md`, `README` to the shared model, ladder, tag/version convention, and flow — matching the structure used across the other three repos.

---

## Acceptance Examples

- AE1. *When a PR is opened into `develop`*, the emulator builds and its automated tests run; both must be green before merge. Covers: R1, R4.
- AE2. *When a commit merges to `develop`*, CI tags `vX.Y.Z-alpha.N` and publishes the alpha build. Covers: R5, R3.
- AE3. *When a `release/X.Y.Z → main` PR has red beta checks*, the merge is blocked. Covers: R2, R3.
- AE4. *When the release PR merges to `main`*, `vX.Y.Z` is tagged and the already-built artifact is published — no build runs on `main`. Covers: R7, R3.

---

## Success Criteria

- The repo runs the identical branch/ladder/tag standard as firmware, app, proto — set up from scratch, no legacy to undo.
- The app can validate its alpha against a tagged emulator build with confidence in its fidelity.
- `main` has zero failable build/publish jobs; clean SemVer tags from `0.1.0-alpha` onward.

---

## Scope Boundaries

- No external-tester cohorts; no nightly.
- No maintenance branches / backporting (latest-only-supported).
- Not cutting `1.0.0`.
- The emulator's functional scope/behavior itself is out of scope here — this doc is only the CI/CD + workflow setup.
- Implementation specifics (workflow YAML, ruleset JSON, bump-tool config, build tooling) → plan.

---

## Key Decisions

- Establish the standard fresh (greenfield) rather than refactor.
- Build-in-PR / tag-on-merge; `main` never builds.
- Short-lived `release/X.Y.Z` branch so `develop` keeps flowing.
- alpha = build+tests in isolation; beta = fidelity as a firmware stand-in.
- SemVer version `X.Y.Z`; git tag `vX.Y.Z`. Start at `0.1.0-alpha`.

---

## Dependencies / Cross-repo Coordination

- **proto** — the emulator speaks the contract; it must track proto versions.
- **app** — the primary consumer; the emulator's beta fidelity gates the trustworthiness of the app's alpha. The emulator and app plans likely run **hand-in-hand**.
- **firmware** — the behavior reference the emulator mirrors; fidelity is checked against it.

---

## Outstanding Questions

- What "faithful stand-in" is measured against (a recorded real-firmware behavior fixture? a live device cross-check?) — plan/define.
- Build tooling + where the emulator artifact is published — plan-time.
