#!/bin/bash
# Run a system's ClickBench benchmark locally and write a result JSON into
# <system>/results/<date>/.
#
# Usage:  [MACHINE=..] [TAG=..] ./run-local.sh <system>
#
#   e.g.  ./run-local.sh umbra
#
# The result is written to
#   <system>/results/<date>/<machine>[.<tag>].json
# where <date> is today (UTC, YYYYMMDD); the "date" field inside the JSON is
# the real run date.
#
# The system must provide a benchmark.sh and a parse-result.py that turns the
# run log into the result JSON (using the system's template.json). Run identity
# (MACHINE/TAG) is resolved by the top-level local-env.sh.
set -euo pipefail

system="${1:?usage: ./run-local.sh <system>}"
cd "$(dirname "$0")/$system"

source ../local-env.sh

BENCH_MACHINE="${BENCH_MACHINE:-$MACHINE}"
BENCH_DATE="${BENCH_DATE:-$(date -u +%Y-%m-%d)}"
BENCH_CLUSTER_SIZE="${BENCH_CLUSTER_SIZE:-1}"
BENCH_LOG="${BENCH_LOG:-./run-local.log}"

BENCH_TAG="$TAG"
export BENCH_MACHINE BENCH_DATE BENCH_CLUSTER_SIZE BENCH_TAG

# Run the benchmark, mirroring output to the terminal and the log. set -o
# pipefail makes a benchmark.sh failure propagate through the tee.
./benchmark.sh 2>&1 | tee "$BENCH_LOG"

# Land under results/<date> — today (UTC).
date_dir="$(date -u +%Y%m%d)"
out_dir="results/$date_dir"
mkdir -p "$out_dir"
suffix=""
[ -n "$BENCH_TAG" ] && suffix=".$BENCH_TAG"
out_file="$out_dir/$BENCH_MACHINE$suffix.json"

python3 ../parse-result.py "$BENCH_LOG" > "$out_file"

echo "run-local: wrote $system/$out_file" >&2
