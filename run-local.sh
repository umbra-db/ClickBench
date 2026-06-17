#!/bin/bash
# Run a system's ClickBench benchmark locally and write a result JSON into
# <system>/results/<DATE>/.
#
# Usage:  [DATE=YYYYMMDD] [LOCAL=1|TRACE=1] [VERSION=..] [MACHINE=..] [TAG=..] \
#             ./run-local.sh <system>
#
#   e.g.  ./run-local.sh umbra                  # Docker run, today's date
#         LOCAL=1 ./run-local.sh umbra          # run a locally-built binary
#         DATE=20700101 ./run-local.sh umbra    # land under results/20700101/
#
# The result is written to
#   <system>/results/<DATE>/<machine>.<version>[.<variant>][.<tag>].json
# where DATE defaults to today (UTC, YYYYMMDD) and can be overridden. The
# "date" field inside the JSON is always the real run date, independent of the
# (possibly overridden) folder.
#
# The system must follow the local-run convention umbra established: a
# local-env.sh that resolves LOCAL/TRACE/VERSION/MACHINE/TAG from the
# environment, a benchmark.sh that honours them, and a parse-result.py that
# turns the run log into the result JSON (using the system's template.json).
set -euo pipefail

system="${1:?usage: [DATE=YYYYMMDD] ./run-local.sh <system>}"
cd "$(dirname "$0")/$system"

# Docker by default; opt into a locally-built binary with LOCAL=1 (or TRACE=1,
# which implies LOCAL — see local-env.sh).
source ../local-env.sh

BENCH_MACHINE="${BENCH_MACHINE:-$MACHINE}"
BENCH_DATE="${BENCH_DATE:-$(date -u +%Y-%m-%d)}"
BENCH_CLUSTER_SIZE="${BENCH_CLUSTER_SIZE:-1}"
BENCH_LOG="${BENCH_LOG:-./run-local.log}"

# Run-mode variant for the filename/title. TRACE implies LOCAL (see
# local-env.sh) but gets its own "trace" label, so check it first.
BENCH_VARIANT=""
if [ "$TRACE" -eq 1 ]; then
    BENCH_VARIANT="trace"
elif [ "$LOCAL" -eq 1 ]; then
    BENCH_VARIANT="local"
fi
BENCH_VERSION="$VERSION"
BENCH_TAG="$TAG"
export BENCH_MACHINE BENCH_DATE BENCH_CLUSTER_SIZE BENCH_VERSION BENCH_VARIANT BENCH_TAG

# Run the benchmark, mirroring output to the terminal and the log. set -o
# pipefail makes a benchmark.sh failure propagate through the tee.
./benchmark.sh 2>&1 | tee "$BENCH_LOG"

# Land under results/<DATE> — today (UTC) by default, override with
# DATE=YYYYMMDD (e.g. DATE=20700101 to group with the existing umbra results).
date_dir="${DATE:-$(date -u +%Y%m%d)}"
out_dir="results/$date_dir"
mkdir -p "$out_dir"
# Suffix is the run-mode variant (.local/.trace) followed by the TAG, so a
# tagged local run lands at e.g. epyc3.26.06.local.prefetch.json.
suffix=""
[ -n "$BENCH_VARIANT" ] && suffix=".$BENCH_VARIANT"
[ -n "$BENCH_TAG" ] && suffix="$suffix.$BENCH_TAG"
out_file="$out_dir/$BENCH_MACHINE.$BENCH_VERSION$suffix.json"

python3 ../parse-result.py "$BENCH_LOG" > "$out_file"

echo "run-local: wrote $system/$out_file" >&2
