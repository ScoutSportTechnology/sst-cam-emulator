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
