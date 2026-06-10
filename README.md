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

## Related repos

- [`sst-cam-app`](https://github.com/ScoutSportTechnology/sst-cam-app) — Flutter app; gains a socket `BleService` backend.
- [`sst-cam-firmware`](https://github.com/ScoutSportTechnology/sst-cam-firmware) — Jetson firmware; gains a host build variant with faked hardware ports.
- [`sst-cam-proto`](https://github.com/ScoutSportTechnology/sst-cam-proto) — the BLE/proto wire contract (shared, unchanged by this work).
