#!/bin/bash
# Thin shim — actual flow is in lib/benchmark-common.sh.
#
# Optional local-dev knobs, read by the umbra primitives (start/load/query/
# stop) straight out of the environment, so they need no wiring here:
#   LOCAL=1    run a locally-built Umbra (./bin/server) instead of Docker
#   TRACE=1    implies LOCAL; use ./bin/trace binaries and dump per-query
#              perftracer traces under traces/${MACHINE}.${VERSION}/
#   VERSION    Docker image tag / trace-dir suffix (default "latest")
# e.g.  TRACE=1 ./benchmark.sh
# umbra/load fetches hits.tsv itself (into data/, only if absent) and keeps
# it across runs, so the driver's unconditional download step is disabled
# here to avoid re-downloading the ~70 GB dataset on every run.
export BENCH_DOWNLOAD_SCRIPT=""
export BENCH_DURABLE=yes
exec ../lib/benchmark-common.sh
