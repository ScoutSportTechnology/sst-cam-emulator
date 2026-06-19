#!/usr/bin/env bash
# =============================================================================
# build.sh — the build seam for the SST Cam emulator CI/CD pipeline.
#
# INTENTIONAL CI PLUMBING NO-OP. This is *not* a product skeleton.
#
# The bridge daemon's language/runtime is still deferred to the bridge
# implementation plan (see CLAUDE.md "When implementation starts"), so there is
# nothing concrete to build yet. The four workflows (ci / alpha / release-beta /
# promote) already call this script so the pipeline is wired end-to-end; when the
# bridge language lands, ONLY this file changes — the workflows stay put.
#
# Contract for the future implementation:
#   - Produce the release artifact under dist/ (a glob the alpha/beta workflows
#     upload conditionally). Today nothing is produced, so alpha/beta are
#     tag-only (no asset) — that is the documented seam-window behavior.
#   - Exit non-zero on a real build failure so the `build` required check gates.
#
# Until then: print a clear notice and exit 0. The substantive failable gate in
# the seam window is the `lint` job (shellcheck + actionlint), not this no-op.
# =============================================================================
set -euo pipefail

echo "build.sh: build tooling not yet chosen — implemented by the bridge implementation plan."
echo "build.sh: no artifact produced (seam window); alpha/beta releases are tag-only until the bridge lands."
exit 0
