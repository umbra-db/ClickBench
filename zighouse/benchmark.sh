#!/bin/bash
set -e

# The dataset is fetched inside ./load: JSONEachRow is the only bulk format the
# generic ZigHouse HTTP server can ingest, and there is no shared JSON download
# helper, so there is no separate download step here.
export BENCH_DOWNLOAD_SCRIPT=""
# Skip the concurrent-QPS test by default (see issue #946); override
# BENCH_CONCURRENT_DURATION to run it against the HTTP server.
export BENCH_CONCURRENT_DURATION="${BENCH_CONCURRENT_DURATION:-0}"
exec ../lib/benchmark-common.sh
