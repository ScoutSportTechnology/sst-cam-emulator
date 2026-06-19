#!/usr/bin/env bash
# =============================================================================
# test.sh — the test seam for the SST Cam emulator CI/CD pipeline.
#
# INTENTIONAL CI PLUMBING NO-OP. This is *not* a product skeleton.
#
# The bridge daemon's language/runtime is still deferred to the bridge
# implementation plan (see CLAUDE.md "When implementation starts"), so there is
# no test suite to run yet. The `ci.yml` `test` job already calls this script so
# the pipeline is wired end-to-end; when the bridge language lands, ONLY this
# file changes — the workflow stays put.
#
# Contract for the future implementation:
#   - Run the bridge test suite and exit non-zero on failure so the `test`
#     required check gates merges.
#
# Until then: print a clear notice and exit 0. The substantive failable gate in
# the seam window is the `lint` job (shellcheck + actionlint), not this no-op.
# =============================================================================
set -euo pipefail

echo "test.sh: test tooling not yet chosen — implemented by the bridge implementation plan."
echo "test.sh: no tests to run (seam window); the lint job is the substantive gate until the bridge lands."
exit 0
