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

## Related repos

- [`sst-cam-app`](https://github.com/ScoutSportTechnology/sst-cam-app) — Flutter app; gains a socket `BleService` backend.
- [`sst-cam-firmware`](https://github.com/ScoutSportTechnology/sst-cam-firmware) — Jetson firmware; gains a host build variant with faked hardware ports.
- [`sst-cam-proto`](https://github.com/ScoutSportTechnology/sst-cam-proto) — the BLE/proto wire contract (shared, unchanged by this work).
