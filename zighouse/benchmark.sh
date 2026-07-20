#!/bin/bash
set -e

# The dataset is fetched inside ./load: JSONEachRow is the only bulk format the
# generic ZigHouse HTTP server can ingest, and there is no shared JSON download
# helper, so there is no separate download step here.
export BENCH_DOWNLOAD_SCRIPT=""
export BENCH_DURABLE=yes
exec ../lib/benchmark-common.sh
