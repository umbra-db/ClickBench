#!/bin/bash
# Thin shim — actual flow is in lib/benchmark-common.sh.
export BENCH_DOWNLOAD_SCRIPT="download-hits-parquet-partitioned"
export BENCH_DURABLE=yes
# RESTARTABLE=yes: ./start now launches a persistent hyperd whose lifecycle
# matters, so the driver's cold cycle (stop -> wait_stopped -> drop_caches ->
# start) gives an honest cold try 1 while tries 2..N stay hot on the warm
# server. See issue #936.
export BENCH_RESTARTABLE=yes
exec ../lib/benchmark-common.sh
