#!/usr/bin/env bash
# Benchmark a single ClickHouse version inside Docker.
#
#   ./run-version.sh <version> [image_ref] [phase]
#
# Spins up the server, creates the six tables with version-appropriate DDL
# (create/create.sh), loads the prepared Native files with a plain
# `clickhouse-client INSERT ... FORMAT Native`, then times every query in
# queries/{mgbench,ssb,hits,taxi}.sql (TRIES runs each, dropping the page
# cache between queries) and writes results/<version>.json.
#
# phase (default "all") splits load from benchmark so run-all.sh can load many
# versions in parallel and then benchmark them one at a time:
#   load  - start the container and load data; LEAVE it running.
#   bench - attach to the already-loaded container, run queries, write the
#           result, then remove the container.
#   all   - load + bench + teardown in one go (single-version use).
#
# image_ref comes from list-versions.sh: either "<repo>/clickhouse-server:<v>"
# or the literal "package" (install the .deb into Ubuntu — fallback provider).

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${DATA:-${HERE}/prepare-data/data}"
TRIES="${TRIES:-3}"
MEM=100000000000   # 100G per-query memory limit
# Datasets to actually load. Queries for any skipped dataset still run (and
# report null). E.g. LOAD_DATASETS="hits ssb mgbench" skips the big taxi load
# while keeping its file on disk.
LOAD_DATASETS="${LOAD_DATASETS:-hits ssb mgbench taxi}"

VERSION="${1:?usage: run-version.sh <version> [image_ref] [phase]}"
IMAGE="${2:-}"
PHASE="${3:-all}"
[ -z "${IMAGE}" ] && IMAGE="$(./list-versions.sh | awk -v v="${VERSION}" '$1==v{print $2}')"
[ -z "${IMAGE}" ] && { echo "no image for ${VERSION}" >&2; exit 1; }

CONTAINER="chver_${VERSION//[^0-9A-Za-z]/_}"
OUT="${HERE}/results/${VERSION}.json"

# Datasets => "table:file" pairs to create+load.
declare -A TABLES=(
    [hits]="hits:hits.native.zst"
    [ssb]="lineorder_flat:ssb.native.zst"
    [mgbench]="logs1:mgbench1.native.zst logs2:mgbench2.native.zst logs3:mgbench3.native.zst"
    [taxi]="trips:taxi.native.zst"
)
# Query files are run (and reported) in this fixed order.
QUERY_ORDER="mgbench ssb hits taxi"

cleanup() { sudo docker rm -f "${CONTAINER}" >/dev/null 2>&1; }
# The load phase must leave the container running for the later bench phase;
# all/bench tear it down on exit.
[ "${PHASE}" != "load" ] && trap cleanup EXIT

# Client dispatch. Modern/most images bundle a client (`exec` mode). The oldest
# server images (1.1.54xxx, early 18.x) ship only clickhouse-server, so we drive
# them with the matching-version client image as a sidecar sharing the server's
# network namespace (`sidecar` mode) — same native protocol, precise --time.
CLIENT_IMAGE="${IMAGE/-server/-client}"
CLIENT_MODE=""   # set by start_server: exec | sidecar
# HOME=/tmp: old images set the clickhouse user's home to /nonexistent, so the
# client can't write its history file. TZ=UTC + the zoneinfo mount: some old
# client images ship no tzdata and otherwise fail at startup with "Could not
# determine local time zone" (before any query runs).
exec_client()    { sudo docker exec -i -e HOME=/tmp -e TZ=UTC "${CONTAINER}" clickhouse client "$@"; }
sidecar_client() { sudo docker run --rm -i -e HOME=/tmp -e TZ=UTC \
                       -v /usr/share/zoneinfo:/usr/share/zoneinfo:ro \
                       --network "container:${CONTAINER}" "${CLIENT_IMAGE}" "$@"; }
client() {
    case "${CLIENT_MODE}" in
        sidecar) sidecar_client "$@" ;;
        *)       exec_client "$@" ;;
    esac
}

start_server() {
    cleanup
    if [ "${IMAGE}" = "package" ]; then
        # Fallback provider: install the .deb release into a stock Ubuntu image.
        echo "starting ${VERSION} via package-in-ubuntu fallback" >&2
        sudo docker run -d --name "${CONTAINER}" --ulimit nofile=262144:262144 ubuntu:22.04 \
            sleep infinity >/dev/null
        sudo docker exec "${CONTAINER}" bash -c "
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq && apt-get install -y -qq curl ca-certificates
            curl -fsSL 'https://packages.clickhouse.com/tgz/stable/clickhouse-common-static-${VERSION}-amd64.tgz' -o /tmp/c.tgz
            tar -xzf /tmp/c.tgz -C /tmp && /tmp/clickhouse-common-static-${VERSION}/install/doinst.sh
            curl -fsSL 'https://packages.clickhouse.com/tgz/stable/clickhouse-client-${VERSION}-amd64.tgz' -o /tmp/cl.tgz
            tar -xzf /tmp/cl.tgz -C /tmp && /tmp/clickhouse-client-${VERSION}/install/doinst.sh
            curl -fsSL 'https://packages.clickhouse.com/tgz/stable/clickhouse-server-${VERSION}-amd64.tgz' -o /tmp/cs.tgz
            tar -xzf /tmp/cs.tgz -C /tmp && /tmp/clickhouse-server-${VERSION}/install/doinst.sh --noninteractive
            clickhouse-server --daemon --config /etc/clickhouse-server/config.xml" >&2
    else
        echo "starting ${VERSION} from image ${IMAGE}" >&2
        sudo docker pull "${IMAGE}" >/dev/null 2>&1
        # Mount an IPv4 listen override: old images default to listening on ::
        # (IPv6) and crash on boot when the host has IPv6 disabled.
        sudo docker run -d --name "${CONTAINER}" --ulimit nofile=262144:262144 \
            -v "${HERE}/config/listen.xml:/etc/clickhouse-server/config.d/zz-listen.xml:ro" \
            "${IMAGE}" >/dev/null
    fi
    # Wait for the server to accept queries, detecting the client mode: prefer
    # the bundled client; fall back to the sidecar client image for the oldest
    # server images that ship no client.
    [ "${IMAGE}" != "package" ] && [ -n "${CLIENT_IMAGE}" ] && \
        sudo docker pull "${CLIENT_IMAGE}" >/dev/null 2>&1
    local i
    for i in $(seq 1 "${READY_TIMEOUT:-90}"); do
        if exec_client --query "SELECT 1" >/dev/null 2>&1; then CLIENT_MODE=exec; return 0; fi
        if sidecar_client --query "SELECT 1" </dev/null >/dev/null 2>&1; then CLIENT_MODE=sidecar; return 0; fi
        sleep 1
    done
    echo "server ${VERSION} did not become ready; last container logs:" >&2
    sudo docker logs --tail 20 "${CONTAINER}" >&2 2>&1 || true
    return 1
}

# Load every dataset; tables that fail to create/load are left absent so their
# queries report null.
load_data() {
    local ds pair table file ddl t0
    for ds in ${LOAD_DATASETS}; do
        for pair in ${TABLES[$ds]}; do
            table="${pair%%:*}"; file="${pair##*:}"
            [ -f "${DATA}/${file}" ] || { echo "SKIP ${table}: ${file} not present"; continue; }
            ddl="$("${HERE}/create/create.sh" "${VERSION}" "${table}")"
            echo "=== CREATE ${table} on ${VERSION} ==="
            echo "${ddl}"
            if ! printf '%s' "${ddl}" | client --multiquery; then
                echo "CREATE ${table} FAILED on ${VERSION}"; continue
            fi
            echo "=== INSERT INTO ${table} FORMAT Native  <-  ${file} ($(du -h "${DATA}/${file}" | cut -f1)) ==="
            # Decompress on the host and stream plain Native into the client, so
            # the (possibly ancient) clickhouse-client never sees compression.
            t0=${SECONDS}
            if zstd -dc "${DATA}/${file}" | client --query "INSERT INTO ${table} FORMAT Native"; then
                echo "loaded ${table}: $(client --query "SELECT count() FROM ${table}" 2>/dev/null) rows in $((SECONDS - t0))s"
            else
                echo "LOAD ${table} FAILED on ${VERSION}"
            fi
        done
    done
}

drop_caches() { sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1; }

# </dev/null: the client runs via `docker {exec,run} -i`, which would otherwise
# read the caller's stdin — and the benchmark loop reads its query file on
# stdin, so a bare probe here would swallow the remaining queries.
server_alive() { client --query "SELECT 1" </dev/null >/dev/null 2>&1; }

# Bring the server back after a crash. An OOM kill takes down clickhouse-server
# (PID 1 for image providers), so the container exits — but its data layer
# survives, so `docker start` restarts it with the loaded tables intact. For the
# package provider the container (PID 1 = sleep) stays up, so relaunch the daemon.
revive_server() {
    if [ "$(sudo docker inspect -f '{{.State.Running}}' "${CONTAINER}" 2>/dev/null)" != "true" ]; then
        sudo docker start "${CONTAINER}" >/dev/null 2>&1
    elif [ "${IMAGE}" = "package" ]; then
        sudo docker exec -d "${CONTAINER}" clickhouse-server --daemon --config /etc/clickhouse-server/config.xml 2>/dev/null
    fi
    local i
    for i in $(seq 1 "${READY_TIMEOUT:-90}"); do server_alive && return 0; sleep 1; done
    return 1
}

# Run one query TRIES times, print a JSON array "[t1, t2, t3]" (null on error).
# If the server dies mid-query (e.g. OOM-killed), revive it and retry up to
# CRASH_RETRIES times so one heavy query doesn't null out the whole version.
run_query() {
    local query="$1" i res crash out="["
    for i in $(seq 1 "${TRIES}"); do
        crash=0
        while :; do
            res=$(printf '%s' "${query}" | client --time --max_memory_usage="${MEM}" --format=Null 2>&1)
            [[ "${res}" =~ ^[0-9]+\.[0-9]+$ ]] && break
            if ! server_alive && [ "${crash}" -lt "${CRASH_RETRIES:-2}" ]; then
                crash=$((crash + 1))
                echo "${VERSION}: server died mid-query (likely OOM); reviving (retry ${crash})" >&2
                revive_server && continue
            fi
            res="null"; break
        done
        out+="${res}"
        [ "${i}" -ne "${TRIES}" ] && out+=", "
    done
    echo "${out}]"
}

# Attach to an already-running, already-loaded container (bench phase): detect
# the client mode without (re)starting or wiping the container.
detect_client() {
    sudo docker ps -q -f "name=^${CONTAINER}$" | grep -q . || { echo "container ${CONTAINER} not running" >&2; return 1; }
    [ "${IMAGE}" != "package" ] && [ -n "${CLIENT_IMAGE}" ] && sudo docker pull "${CLIENT_IMAGE}" >/dev/null 2>&1
    local i
    for i in $(seq 1 30); do
        if exec_client --query "SELECT 1" >/dev/null 2>&1; then CLIENT_MODE=exec; return 0; fi
        if sidecar_client --query "SELECT 1" </dev/null >/dev/null 2>&1; then CLIENT_MODE=sidecar; return 0; fi
        sleep 1
    done
    return 1
}

# Time every query and write results/<version>.json.
run_benchmark() {
    local ACTUAL ds query FIRST=1
    ACTUAL=$(client --query "SELECT version()" 2>/dev/null | tr -d '\r')
    echo "benchmarking ${VERSION} (server reports ${ACTUAL})" >&2
    {
        echo '{'
        echo "    \"version\": \"${VERSION}\","
        echo "    \"actual_version\": \"${ACTUAL}\","
        echo '    "result":'
        echo '    ['
        for ds in ${QUERY_ORDER}; do
            # Read queries on FD 3 (not stdin) so the per-query `docker exec/run -i`
            # client calls can't consume the query file.
            while IFS= read -r query <&3; do
                [ -z "${query}" ] && continue
                query="${query%;}"                       # strip trailing semicolon
                drop_caches
                [ "${FIRST}" = 0 ] && echo ','
                FIRST=0
                printf '%s' "$(run_query "${query}")"
            done 3< "${HERE}/queries/${ds}.sql"
        done
        echo
        echo '    ]'
        echo '}'
    } > "${OUT}"
    echo "wrote ${OUT}" >&2
}

# ---- run ----
case "${PHASE}" in
    load)
        start_server || exit 1
        echo "loading ${VERSION} ..." >&2
        load_data
        echo "loaded ${VERSION}; leaving container running for bench phase" >&2
        ;;
    bench)
        detect_client || { echo "cannot attach to ${VERSION} for bench" >&2; exit 1; }
        run_benchmark
        ;;
    all|*)
        start_server || exit 1
        load_data
        run_benchmark
        ;;
esac
