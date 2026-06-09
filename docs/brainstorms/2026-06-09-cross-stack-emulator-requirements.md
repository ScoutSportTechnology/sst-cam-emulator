---
date: 2026-06-09
topic: cross-stack-emulator
---

# Cross-Stack Emulator for App↔Firmware Testing Without Hardware

## Summary

A cross-stack emulator that lets `sst-cam-app` and `sst-cam-firmware` run and test against each other without a Jetson. Delivered in phases: (A) a hardware-free firmware build variant whose tests run green in-container, then (B) a standalone bridge daemon that connects the real app to the emulated firmware over a local socket carrying the existing proto frames, then conformance coverage for protocol-aligned behavior.

---

## Problem Frame

The system is three repos sharing one BLE/proto contract: `sst-cam-app` (Flutter), `sst-cam-firmware` (C++/Jetson cross-compile), `sst-cam-proto` (the contract). The app can already swap its firmware-facing layer for an in-process double (`MockBleService`, selected at runtime by `kAppEnv.isDevBackend`). The firmware has no equivalent: its hardware-bound surfaces (IMX477 capture, NVENC, BlueZ/GATT, wpa/wifi, HTTP download) cannot run in the dev container, so a chunk of its test suite fails by design and is read as "expected failures" — noise that hides real regressions.

More acutely, there is **no way to exercise app↔firmware interaction end-to-end without real hardware**. The just-completed logic-alignment work aligned the app's encoders with the firmware's decoders against the contract, but two correctness fixes could not be verified anywhere — score routing (the app must send the configured team id, the firmware routes by it) and the connect-time `protocol_version` handshake (the app must refuse a skewed session). Both compile and pass their isolated unit pieces, but the actual cross-stack behavior they fix is only observable when a real app talks to a real firmware. Every future protocol change inherits the same blind spot.

---

## Actors

- A1. Developer / CI: runs firmware tests and app↔firmware interaction tests on a laptop or CI runner with no Jetson.
- A2. `sst-cam-app` (real build): the unmodified app, reaching the emulated firmware through a socket-based BLE backend selected by `kAppEnv`.
- A3. `sst-cam-firmware` (emulated build): the real firmware binary built on host with hardware-bound ports replaced by in-process fakes.
- A4. Bridge daemon (new, `sst-cam-emulator`): the intermediary that routes proto frames between the real app and the emulated firmware and models device lifecycle (discovery, identity).

---

## Key Flows

- F1. Emulated firmware test run (Phase A)
  - **Trigger:** developer/CI builds firmware with the emulated profile.
  - **Actors:** A1, A3
  - **Steps:** configure build with the emulated flag → hardware ports resolve to in-process fakes → run the test suite → emulator-safe tests execute, hardware-only tests are excluded by label.
  - **Outcome:** a fully green firmware suite on host; no "expected failure" noise.
  - **Covered by:** R1, R2, R3

- F2. App ↔ emulated firmware, end-to-end (Phase B)
  - **Trigger:** developer/CI launches the emulated firmware + the bridge, then runs the app against it.
  - **Actors:** A1, A2, A3, A4
  - **Steps:** start emulated firmware → start bridge (advertising the emulated device with a configured identity) → real app, on its socket backend, scans/filters/connects through the bridge → app drives a session (device info, session config, overlay, score/banner events) → assertions on firmware state and responses.
  - **Outcome:** the full app↔firmware loop runs with zero hardware; the two motivating P1s are observable.
  - **Covered by:** R4, R5, R6, R7, R8, R10
  - **Escape path:** identity/version mismatch surfaces as a clean app-side version-skew refusal (AE1).

- F3. Firmware against an emulated app (reverse direction)
  - **Trigger:** a firmware test or dev session needs to drive the firmware with app-shaped traffic.
  - **Actors:** A1, A3, A4
  - **Steps:** drive the emulated firmware with scripted/canned app-side proto exchanges (a fake app) → assert firmware responses and state transitions.
  - **Outcome:** firmware behavior is testable against representative app traffic without the real app.
  - **Covered by:** R9

---

## Requirements

**Emulated firmware build (Phase A)**
- R1. The firmware must build and run on host with every hardware-bound port replaced by an in-process fake, selected by a build-time profile/flag (not a runtime branch sprinkled through logic).
- R2. Tests must be labeled by the environment they need; the emulated build runs emulator-safe tests and excludes hardware-only tests by label, so a clean run has no failing cases rather than a known-failing baseline.
- R3. The fakes must cover the surfaces that currently fail in-container: camera/IMX477 capture, NVENC encode, BlueZ/GATT transport, wpa/wifi, HTTP download — at the fidelity needed for protocol/control tests, not signal fidelity.

**Cross-stack transport (Phase B)**
- R4. An alternate transport must carry the existing `ChunkedPayload` proto frames over a local socket; framing, chunking, the ChunkAck flow-control convention, and the command/response handlers stay unchanged — only the carrier differs from GATT.
- R5. The app must gain a socket-based `BleService` backend selected through the existing `kAppEnv` dev-environment switch, as a third backend alongside the real `flutter_blue_plus` impl and the in-process `MockBleService`.
- R6. The emulated firmware must expose its full control/response surface over the socket transport.

**Bridge (Phase B)**
- R7. A standalone bridge process must route proto frames between the real app and the emulated firmware.
- R8. The bridge must let the emulated device's identity be configured — at minimum `protocol_version` and device name — so the discovery/connect and version-skew paths are testable.
- R9. The harness must support both directions: real app ↔ emulated firmware, and emulated app ↔ real (emulated-build) firmware via scripted/canned app traffic.

**Bridge platform — fault injection & session tooling**
- R12. The bridge must support fault injection on the transport: configurable latency, dropped/duplicated chunks, mid-transfer disconnect, forced MTU, and forced `protocol_version` skew — so the chunk-ack/timeout, index-reassembly, and disconnect-cleanup paths are deterministically testable.
- R13. The bridge must support recording a session's frame exchange and replaying it deterministically, so a captured failure becomes a regression test.
- R14. The bridge must provide an inspection surface — at minimum a live log of routed frames and injected fault events; a small UI is acceptable but optional.

**Conformance**
- R10. The two motivating cross-stack behaviors must become testable end-to-end: score routing by team id, and the connect-time `protocol_version` handshake/refusal.
- R11. Shared conformance vectors (golden proto exchanges) should exist that both stacks can validate against, so a contract change surfaces drift on both sides.

---

## Acceptance Examples

- AE1. **Covers R8, R10.** Given the emulated firmware is configured with a `protocol_version` different from the app's, when the app connects through the bridge, the app refuses the session with a version-skew error (exercises the connect handshake fix).
- AE2. **Covers R6, R10.** Given a connected app↔emulated-firmware session, when the app sends a Goal event for the home team, the emulated firmware increments the home team's score (exercises the score-routing fix end-to-end).
- AE3. **Covers R2.** Given the emulated build, when the test suite runs, no hardware-bound test appears as a failure — hardware-only cases are excluded by label, not failed.
- AE4. **Covers R12.** Given the bridge is configured to drop one inbound command chunk, when the app sends a multi-chunk command, the app surfaces a clean timeout (not a hang or a duplicated action), exercising the chunk-ack reliability path.

---

## Success Criteria

- A developer can run app↔firmware interaction tests on a laptop with no Jetson attached.
- The firmware suite is green under the emulated build — "expected failures" stop masking real regressions.
- The two P1 fixes, and future protocol changes, are covered by automated cross-stack tests rather than manual on-device checks.
- The handoff to planning is clean: Phase A is buildable and valuable on its own, before any bridge work begins.

---

## Scope Boundaries

- Not emulating AI/tracking/physics/pipeline compute or signal fidelity — only the control/protocol and I/O surfaces needed for interaction and contract tests.
- Not pixel-accurate render emulation; overlay-render conformance stays per-repo (the contract tolerance model already covers it).
- Not emulating real BLE at the OS level (no virtual BlueZ device); the app reaches the bridge via a socket backend instead.
- v1 bridge does not require fault injection (latency/drops/MTU), session record-replay, or a UI — these are deferred.
- Not a production or shipping artifact — development and test only.

---

## Key Decisions

- **Emulated firmware is a build variant of `sst-cam-firmware`, not a new repo.** This mirrors Trezor (`core/emulator` is a firmware build, not a separate project). The emulator is the same firmware with hardware ports swapped; the hexagonal ports/adapters architecture is what makes the swap clean.
- **A new repo `sst-cam-emulator` is justified, but scoped to the bridge daemon + cross-stack dev tooling + shared conformance vectors only.** The bridge is the one genuinely cross-stack, language-neutral component. The per-language transport adapters live in their own repos (socket `BleService` in `sst-cam-app`, socket adapter in `sst-cam-firmware`).
- **Transport reuses the contract: a local socket carries existing `ChunkedPayload` frames; only the carrier changes** (GATT → socket). Minimal new surface, and the framing/chunking/ack logic is exercised as-is.
- **The app emulator backend reuses the `kAppEnv.isDevBackend` selection pattern** as a third backend, for consistency with the existing mock.
- **Phasing: A → B → conformance.** Phase A (emulated firmware build + green CI) delivers standalone value before the bridge exists.

---

## Dependencies / Assumptions

- Assumes the firmware's hexagonal port boundaries are complete enough that camera/encoder/BLE/wifi/HTTP can each be swapped for a fake without invasive refactoring. Some surfaces may need a cleaner seam first — verify per-port during planning.
- The proto3 contract remains the single source of the wire frames (already shared via the `proto/` submodule), so both the GATT and socket carriers serialize identical bytes.

---

## Outstanding Questions

### Resolve Before Planning

- [Affects R7, R8][User decision] Bridge day-one scope — route-only relay vs route + device-lifecycle (discovery/identity) vs full platform (fault injection + record/replay + UI). Recommended starting point: route + device-lifecycle, since it makes both motivating P1s (version skew + discovery/connect) testable without over-building.

### Deferred to Planning

- [Affects R7][Technical] Bridge implementation language/runtime (language-neutral; pick for ease of socket + proto handling and dev ergonomics).
- [Affects R1, R2][Technical] The build-profile mechanism and test-label scheme for the emulated firmware (e.g. CMake option + ctest labels).
- [Affects R9][Needs research] Best mechanism for the emulated-app→firmware direction — scripted conformance-vector replay vs a fake-app mode inside the bridge.
- [Affects R1, R3][Needs research] Which hardware ports already have a clean seam to fake vs which need a refactor first.
- [Affects R5][Technical] How the app's socket backend handles discovery/scan results surfaced by the bridge within the existing `BleService` interface.
