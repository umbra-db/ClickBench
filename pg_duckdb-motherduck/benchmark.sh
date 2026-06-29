#!/bin/bash
# Thin shim — actual flow is in lib/benchmark-common.sh.
# Empty BENCH_DOWNLOAD_SCRIPT: the data lives in MotherDuck cloud (the
# load script CTAS'es directly from S3 inside MotherDuck), nothing to
# fetch locally.
export BENCH_DOWNLOAD_SCRIPT=""
exec ../lib/benchmark-common.sh
