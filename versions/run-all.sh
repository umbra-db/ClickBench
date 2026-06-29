#!/usr/bin/env bash
# Run the Versions Benchmark across every selected version.
#
#   ./run-all.sh            # all versions from list-versions.sh
#   ./run-all.sh 1.1.54378 24.8.1.1 ...   # only the given versions
#
# Each version is benchmarked in its own container by run-version.sh, which
# writes results/<version>.json. Prepared Native files must already exist
# (see prepare-data/prepare.sh). Failures on one version don't stop the sweep.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${HERE}"

if [ "$#" -gt 0 ]; then
    # Benchmark only the named versions (image resolved inside run-version.sh).
    for v in "$@"; do
        echo "######## ${v} ########"
        ./run-version.sh "${v}" </dev/null || echo "FAILED: ${v}" >&2
    done
else
    # Materialise the list first: run-version.sh runs `docker exec -i`, which
    # would otherwise drain this loop's stdin (the version list) and stop it
    # after one iteration. Reading from a temp file + redirecting run-version's
    # stdin from /dev/null keeps the list intact.
    LIST="$(mktemp)"; trap 'rm -f "${LIST}"' EXIT
    ./list-versions.sh > "${LIST}"
    while IFS=$'\t' read -r version image date; do
        [ "${image}" = "unavailable" ] && { echo "skip ${version} (${date}): no image or package published" >&2; continue; }
        echo "######## ${version} (${image}, ${date}) ########"
        ./run-version.sh "${version}" "${image}" </dev/null || echo "FAILED: ${version}" >&2
    done < "${LIST}"
fi
