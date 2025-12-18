#!/bin/bash
# Sourced by the umbra primitives (install/start/load/query/stop) to resolve
# the run mode from the environment. Three mutually compatible modes:
#
#   (default)  Docker — pull/run umbradb/umbra:${VERSION}. The original flow.
#   LOCAL=1    Run a locally-built Umbra (./bin/server, ./bin/sql) directly on
#              the host instead of in Docker. The binaries are provided
#              out-of-band (the bin/ dir is gitignored); LOCAL is for hacking
#              on an Umbra build that isn't published as an image yet.
#   TRACE=1    Implies LOCAL, but uses the perftracer-instrumented binaries
#              under ./bin/trace and dumps a per-query .trace into TRACE_DIR.
#
# An optional TAG=<label> distinguishes runs that share a machine/version
# but differ in some build/config knob (e.g. TAG=prefetch). It's appended
# to TRACE_DIR and to the result filename/title — see run-benchmark.
#
# Exports: UMBRA_LOCAL, UMBRA_TRACE (0/1), VERSION, MACHINE, TAG, SQL,
#          SERVER, TRACE_DIR, SERVER_PID_FILE.
UMBRA_TRACE=${TRACE:-0}
UMBRA_LOCAL=${LOCAL:-0}
VERSION=${VERSION:-latest}
MACHINE=${MACHINE:-$(hostname)}
TAG=${TAG:-}
SERVER_PID_FILE=server.pid
SQL=""
SERVER=""

if [ "$UMBRA_TRACE" -eq 1 ]; then
    UMBRA_LOCAL=1
    SQL=./bin/trace/sql
    SERVER=./bin/trace/server
elif [ "$UMBRA_LOCAL" -eq 1 ]; then
    SQL=./bin/sql
    SERVER=./bin/server
fi

TRACE_DIR="traces/${MACHINE}.${VERSION}${TAG:+.${TAG}}"
