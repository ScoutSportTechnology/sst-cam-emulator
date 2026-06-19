# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Cross-stack emulator tooling for the SST Cam system — lets [`sst-cam-app`](https://github.com/ScoutSportTechnology/sst-cam-app)
and [`sst-cam-firmware`](https://github.com/ScoutSportTechnology/sst-cam-firmware)
run and test against each other **without a Jetson**.

> **Brainstorm stage — no code yet.** The spec is
> [`docs/brainstorms/2026-06-09-cross-stack-emulator-requirements.md`](docs/brainstorms/2026-06-09-cross-stack-emulator-requirements.md).
> Read it before writing anything here; do not invent structure ahead of the plan.

## The boundary — what this repo owns

This repo owns **only the bridge daemon + cross-stack dev tooling + shared
conformance vectors** — the one genuinely cross-stack, language-neutral piece.
It is **not** the firmware emulator and **not** the app's socket backend:

- **Emulated firmware** is a *build variant of `sst-cam-firmware`* (hardware-bound
  ports swapped for in-process fakes via a build-time profile), mirroring Trezor's
  `core/emulator`. Lives in the firmware repo, not here.
- **App socket backend** is a third `BleService` impl in `sst-cam-app`, selected by
  the existing `kAppEnv.isDevBackend` switch alongside the real and mock backends.
  Lives in the app repo, not here.

When work touches those halves, it belongs in those repos. Keep this repo to the
bridge and the shared vectors.

## What the bridge does

Routes the existing `ChunkedPayload` proto frames between the real app and the
emulated firmware over a **local socket** — only the carrier changes (GATT →
socket); framing, chunking, the `ChunkAck` flow-control convention, and the
command/response handlers stay byte-identical. It also models device lifecycle
(discovery + configurable identity: `protocol_version`, name) so the
discovery/connect and version-skew paths are testable.

The proto3 contract ([`sst-cam-proto`](https://github.com/ScoutSportTechnology/sst-cam-proto))
stays the single source of the wire frames — both the GATT and socket carriers
serialize identical bytes. This repo does **not** redefine the contract.

## Roadmap / phasing

Per the brainstorm, value ships in order — each phase is useful before the next exists:

1. **Phase A — emulated firmware build** (in `sst-cam-firmware`): host build with
   faked hardware ports, tests labeled by environment so the suite runs green with
   no "expected failure" noise. *Standalone value before any bridge work.*
2. **Phase B — bridge daemon** (this repo): route-only relay → + device lifecycle
   (recommended day-one scope) → optional full platform (fault injection,
   record/replay, inspection UI).
3. **Conformance** — golden proto exchanges both stacks validate against, so a
   contract change surfaces drift on both sides.

The two motivating cross-stack behaviors that must become end-to-end testable:
**score routing by team id** and the **connect-time `protocol_version` handshake/refusal.**

## Scope boundaries (from the brainstorm)

- Not emulating AI/tracking/physics/pipeline compute or signal fidelity — only the
  control/protocol and I/O surfaces.
- Not pixel-accurate render emulation — overlay-render conformance stays per-repo.
- Not real BLE at the OS level (no virtual BlueZ) — the app reaches the bridge via a socket.
- Not a production artifact — development and test only.

## When implementation starts

The bridge language/runtime is deferred to planning (pick for socket + proto
ergonomics; it is language-neutral). Update this file with build/run/test commands
and the actual layout once they exist — until then there is nothing to build.

## CI/CD & releasing

Shared SST workflow standard — same branch model, maturity ladder, and tag
scheme as `sst-cam-app`, `sst-cam-firmware`, and `sst-cam-proto`.

### Branch flow

```
feat/* | fix/*  ──PR──►  develop  ──cut──►  release/X.Y.Z  ──PR──►  main
```

- `develop` — default branch; integration target for `feat/*`/`fix/*`.
- `release/X.Y.Z` — release-candidate branch; betas iterate here.
- `main` — stable; **never runs a failable build job**.

### Maturity ladder + tags `vX.Y.Z[-alpha.N|-beta.N]`

- **alpha** (`vX.Y.Z-alpha.N`) — build + automated tests in isolation. Minted on
  every push to `develop`.
- **beta** (`vX.Y.Z-beta.N`) — fidelity as a firmware stand-in; the app validates
  its own alpha against this. Minted on pushes to `release/X.Y.Z`.
- **stable** (`vX.Y.Z`) — shipped; promoted from the chosen beta by copying its
  artifact, no rebuild.

SemVer prerelease precedence: `-alpha.N` < `-beta.N` < stable. Conventional
Commits drive the bump (`feat:` → minor, `fix:`/`perf:` → patch, `BREAKING`/
`type!:` → major; docs/chore-only → mint nothing).

### Three branch-scoped workflows

Each workflow owns one branch class and folds the PR gate (`Lint (shellcheck +
actionlint)`/`Build`/`Test`) inline, gated to `pull_request`. There is **no
standalone `ci.yml`** — the checks live inside the alpha/beta workflows.

- `.github/workflows/release-alpha.yml` (name `release-alpha`) — owns `develop`.
  `pull_request: [develop]` runs the three gate checks; `push: [develop]` (+
  `workflow_dispatch`) tags + publishes `-alpha.N`.
- `.github/workflows/release-beta.yml` (name `release-beta`) — owns `release/**`.
  `pull_request: [release/**]` runs the same three gate checks; `push:
  [release/**]` tags + publishes `-beta.N`.
- `.github/workflows/release.yml` (name `release`) — owns `main`. `push: [main]`
  promotes (tag `vX.Y.Z` + **copy** the beta artifact). No checks, no build —
  main never builds.

The PR-gate job names are unchanged (`Lint (shellcheck + actionlint)` / `Build` /
`Test`), so the rulesets that require them are unaffected by the consolidation.

### Two non-negotiables

1. **`main` never builds.** Promotion copies the already-built beta artifact;
   there is no build step in `release.yml`.
2. **Green is meaningful.** A genuinely-failable `lint` job (shellcheck +
   actionlint) gates every PR.

### The `scripts/ci/` seam (bridge build/test lands here)

- `scripts/ci/resolve-version.sh` — version math (alpha/beta/stable); tested by
  `resolve-version-test.sh`. Do not duplicate this logic in YAML.
- `scripts/ci/build.sh`, `scripts/ci/test.sh` — **intentional no-ops** until the
  bridge language is chosen. The workflows already call them. When the bridge
  lands, **only these two scripts change** — the pipeline stays.

**Seam-window meaning of "green":** while the bridge language is undecided,
`build`/`test` are green-by-no-op and alpha/beta/promotion are **tag-only** (no
asset). "Green" means **plumbing + lint pass, NOT build/test enforcement**. The
substantive failable gate today is `lint`. Do not misread a green pipeline as a
finished/enforced build.

Ruleset application (one-time maintainer runbook) is documented in
[`docs/ci/rulesets.md`](docs/ci/rulesets.md).

## Release lifecycle

The version ladder is driven by **which branch you push to**, not by counters. Tags climb `vX.Y.Z-alpha.N` (develop) → `vX.Y.Z-beta.N` (release/*) → `vX.Y.Z` (main); the math lives in `scripts/ci/resolve-version.sh`.

**Alpha — automatic, every `develop` merge.** `release-alpha.yml` runs `resolve-version.sh alpha`: the base is a Conventional-Commit bump from the latest *stable* tag (or from `v0.0.0` when none exists), and `-alpha.N` increments per merge.

```
feat A → develop   →  v0.1.0-alpha.1
feat B → develop   →  v0.1.0-alpha.2
feat C → develop   →  v0.1.0-alpha.3
```

With no stable tag yet, a `feat:` yields base `0.1.0` (a `feat!:`/`BREAKING CHANGE` → `1.0.0`; a `fix:`-only → `0.0.1`); docs/chore-only mints nothing.

**Beta — when you cut the release branch.** Manually branch `release/X.Y.Z` off `develop` and push it; `release-beta.yml` runs `resolve-version.sh beta X.Y.Z` (base = the branch name):

```
git switch -c release/0.1.0 develop && git push   →  v0.1.0-beta.1
```

Each subsequent push to that branch bumps the beta counter — `-beta.2`, `-beta.3`, … This is the rung validated as a **faithful firmware stand-in the app runs against**. Alpha and beta are independent counters.

**Stable — when you merge `release/X.Y.Z → main`.** Pushing the branch *creates* the betas; **merging it to `main` promotes the latest beta to stable.** `release.yml` auto-selects the highest `vX.Y.Z-beta.N`, tags `vX.Y.Z`, and copies the beta artifact to the stable Release — no build on `main`. (During the seam window the build/test scripts are no-ops, so alpha/beta/stable are **tag-only** until the bridge build lands.)

```
develop:        alpha.1   alpha.2   alpha.3
                                       │ cut release/0.1.0
release/0.1.0:                         └─► beta.1 → beta.2 → beta.3
                                                              │ merge → main
main:                                                         └─► v0.1.0  (stable)
```

After `v0.1.0` stable exists, the next `feat:` on `develop` bumps from the latest stable → `v0.2.0-alpha.1` (a `fix:` → `v0.1.1-alpha.1`). The alpha base climbs only once a stable is cut.
