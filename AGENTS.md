# AGENTS.md

Guidance for coding agents working in this repository. This mirrors
[`CLAUDE.md`](CLAUDE.md) — read that for the full repo boundary and roadmap; this
file is the agent-facing quick reference for the workflow standard.

## What this is

Cross-stack emulator tooling for the SST Cam system — the **bridge daemon** that
lets `sst-cam-app` and `sst-cam-firmware` run and test against each other without
a Jetson. This repo owns **only** the bridge daemon + cross-stack dev tooling +
shared conformance vectors. The emulated firmware is a build variant of
`sst-cam-firmware`; the app's socket backend lives in `sst-cam-app`. Do not add
product/bridge code ahead of the bridge implementation plan — the language is
still deferred (see `CLAUDE.md` "When implementation starts").

## CI/CD & releasing

Shared SST workflow standard — same branch model, maturity ladder, and tag scheme
as `sst-cam-app`, `sst-cam-firmware`, and `sst-cam-proto`.

### Branch flow

```
feat/* | fix/*  ──PR──►  develop  ──cut──►  release/X.Y.Z  ──PR──►  main
```

- `develop` — default branch; target your `feat/*`/`fix/*` PRs here.
- `release/X.Y.Z` — release-candidate branch; betas iterate here.
- `main` — stable; **never runs a failable build job**.

### Maturity ladder + tags `vX.Y.Z[-alpha.N|-beta.N]`

- **alpha** (`vX.Y.Z-alpha.N`) — build + automated tests in isolation; minted on
  push to `develop`.
- **beta** (`vX.Y.Z-beta.N`) — fidelity as a firmware stand-in (the app validates
  its alpha against it); minted on push to `release/X.Y.Z`.
- **stable** (`vX.Y.Z`) — shipped; promoted from a beta by copying its artifact,
  no rebuild.

Precedence `-alpha.N` < `-beta.N` < stable. Use **Conventional Commits** — the bump
source (`feat:` → minor, `fix:`/`perf:` → patch, `BREAKING`/`type!:` → major;
docs/chore-only mints nothing).

### Three branch-scoped workflows

Each workflow owns one branch class and folds the PR gate (`Lint (shellcheck +
actionlint)`/`Build`/`Test`) inline, gated to `pull_request`. There is **no
standalone `ci.yml`**.

- `.github/workflows/release-alpha.yml` (name `release-alpha`) — owns `develop`.
  `pull_request: [develop]` runs the three gate checks; `push: [develop]` (+
  `workflow_dispatch`) tags + publishes `-alpha.N`.
- `.github/workflows/release-beta.yml` (name `release-beta`) — owns `release/**`.
  `pull_request: [release/**]` runs the same three checks; `push: [release/**]`
  tags + publishes `-beta.N`.
- `.github/workflows/release.yml` (name `release`) — owns `main`. `push: [main]`
  promotes: tag `vX.Y.Z` + **copy** the beta artifact. No checks, no build.

Job names are unchanged (`Lint (shellcheck + actionlint)` / `Build` / `Test`), so
the required-status-check rulesets are unaffected.

### Two non-negotiables

1. **`main` never builds.** Promotion copies the already-built beta artifact.
   Never add a build step to `release.yml` or the main path.
2. **Green is meaningful.** A failable `lint` job (shellcheck + actionlint) gates
   every PR.

### The `scripts/ci/` seam

The bridge build/test commands land here when the language is chosen:

- `scripts/ci/resolve-version.sh` (+ `resolve-version-test.sh`) — version math.
  Tested; do not duplicate in YAML.
- `scripts/ci/build.sh`, `scripts/ci/test.sh` — **intentional no-ops** today. The
  workflows already call them; when the bridge lands, change **only these two
  scripts** — the pipeline stays.

**Seam-window meaning of "green":** while the bridge language is undecided,
`build`/`test` are green-by-no-op and alpha/beta/promotion are **tag-only** (no
asset). Green means **plumbing + lint pass, NOT build/test enforcement**. The
substantive failable gate today is `lint`.

Ruleset application is a one-time maintainer runbook in
[`docs/ci/rulesets.md`](docs/ci/rulesets.md).
