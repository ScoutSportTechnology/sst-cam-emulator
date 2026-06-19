# sst-cam-emulator

Cross-stack emulator and bridge for the SST Cam system — lets `sst-cam-app` and
`sst-cam-firmware` run and test against each other **without a Jetson**.

> Status: **brainstorm stage.** No implementation yet. See
> [`docs/brainstorms/2026-06-09-cross-stack-emulator-requirements.md`](docs/brainstorms/2026-06-09-cross-stack-emulator-requirements.md)
> for the requirements and decisions.

## What lives here

This repo owns the **bridge daemon** and cross-stack dev/test tooling — the one
genuinely cross-stack, language-neutral component. It is *not* the firmware
emulator itself: the emulated firmware is a **build variant of
`sst-cam-firmware`** (mirroring Trezor's `core/emulator`), and the app's socket
backend lives in `sst-cam-app`.

Planned scope (per the brainstorm):

- **Bridge daemon** — routes `ChunkedPayload` proto frames between the real app
  and the emulated firmware over a local socket; emulates device discovery and
  configurable device identity (`protocol_version`, name).
- **Fault injection** — latency, dropped/duplicated chunks, mid-transfer
  disconnect, forced MTU, forced version skew — to exercise the chunk-ack /
  reassembly / disconnect-cleanup paths deterministically.
- **Session record / replay** — capture a frame exchange and replay it as a
  regression test.
- **Conformance vectors** — golden proto exchanges both stacks validate against.

## Roadmap

Cross-stack tooling — its job is to let the app and firmware exercise each other
without a Jetson, so it tracks the system arc one step behind: it can only
emulate a phase once the wire shape exists in
[`sst-cam-proto`](https://github.com/ScoutSportTechnology/sst-cam-proto).

| Phase | Goal | Status |
| ----- | ---- | ------ |
| 0 | **Requirements** — scope, boundaries, decisions | ✅ done ([brainstorm](docs/brainstorms/2026-06-09-cross-stack-emulator-requirements.md)) |
| 1 | **Bridge daemon** — route `ChunkedPayload` frames app ↔ emulated firmware over a local socket; emulate discovery + device identity | ⬜ not started |
| 2 | **Fault injection** — latency, dropped/duplicated chunks, mid-transfer disconnect, forced MTU/version skew | ⬜ not started |
| 3 | **Record / replay** — capture a frame exchange, replay it as a regression test | ⬜ not started |
| 4 | **Conformance vectors** — golden proto exchanges both stacks validate against | ⬜ not started |

This repo owns the bridge only. The two halves it connects live elsewhere: the
emulated firmware is a **build variant of `sst-cam-firmware`**, and the app's
socket backend lives in **`sst-cam-app`** — both tracked in those repos.

## CI/CD & releasing

This repo follows the shared SST workflow standard (same branch model, maturity
ladder, and tag scheme as `sst-cam-app`, `sst-cam-firmware`, and `sst-cam-proto`).

**Branch flow:** `feat/* | fix/*` → `develop` → `release/X.Y.Z` → `main`.

**Maturity ladder** (tags `vX.Y.Z[-alpha.N|-beta.N]`):

| Rung | Tag | Meaning | Minted on |
| ---- | --- | ------- | --------- |
| alpha | `vX.Y.Z-alpha.N` | build + automated tests in isolation | push to `develop` |
| beta | `vX.Y.Z-beta.N` | fidelity as a firmware stand-in (the app validates its alpha against it) | push to `release/X.Y.Z` |
| stable | `vX.Y.Z` | shipped — promoted from a beta by copying its artifact | merge to `main` |

**Four workflows:** `ci.yml` (PR gate: lint/build/test), `alpha.yml`,
`release-beta.yml`, and `promote.yml`.

**Two non-negotiables:** (1) `main` never runs a failable build job — promotion
*copies* the already-built beta artifact; (2) a genuinely-failable `lint` job
(shellcheck + actionlint) gates every PR.

> **Seam window.** The bridge language/runtime is not chosen yet, so the actual
> build/test commands live behind a thin seam — `scripts/ci/build.sh` and
> `scripts/ci/test.sh` are intentional no-ops today. While that holds, "green"
> means **plumbing + lint pass, not build/test enforcement**, and alpha/beta/
> stable releases are **tag-only** (no asset). When the bridge lands, only those
> two scripts change — the pipeline stays. See `CLAUDE.md` and
> [`docs/ci/rulesets.md`](docs/ci/rulesets.md).

## Related repos

- [`sst-cam-app`](https://github.com/ScoutSportTechnology/sst-cam-app) — Flutter app; gains a socket `BleService` backend.
- [`sst-cam-firmware`](https://github.com/ScoutSportTechnology/sst-cam-firmware) — Jetson firmware; gains a host build variant with faked hardware ports.
- [`sst-cam-proto`](https://github.com/ScoutSportTechnology/sst-cam-proto) — the BLE/proto wire contract (shared, unchanged by this work).
