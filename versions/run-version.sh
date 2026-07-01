#!/usr/bin/env bash
# Benchmark a single ClickHouse version inside Docker.
#
#   ./run-version.sh <version> [image_ref] [phase]
#
# Spins up the server, creates the six tables with version-appropriate DDL
# (create/create.sh), loads the prepared Native files with a plain
# `clickhouse-client INSERT ... FORMAT Native`, then times every query in
# queries/{mgbench,ssb,hits,tpch,tpcds,coffeeshop,ontime,uk,job,taxi}.sql (TRIES runs each, dropping the page
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
TRIES="${TRIES:-6}"   # 1 cold + 5 hot runs
MEM=100000000000   # 100G per-query memory limit
# Datasets to actually load. Queries for any skipped dataset still run (and
# report null). E.g. LOAD_DATASETS="hits ssb mgbench" skips the big taxi load
# while keeping its file on disk.
LOAD_DATASETS="${LOAD_DATASETS:-hits ssb mgbench tpch tpcds coffeeshop ontime uk job taxi}"

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
    [tpch]="nation:tpch_nation.native.zst region:tpch_region.native.zst part:tpch_part.native.zst supplier:tpch_supplier.native.zst partsupp:tpch_partsupp.native.zst customer:tpch_customer.native.zst orders:tpch_orders.native.zst lineitem:tpch_lineitem.native.zst"
    [tpcds]="call_center:tpcds_call_center.native.zst catalog_page:tpcds_catalog_page.native.zst catalog_returns:tpcds_catalog_returns.native.zst catalog_sales:tpcds_catalog_sales.native.zst customer_address:tpcds_customer_address.native.zst customer_demographics:tpcds_customer_demographics.native.zst customer:tpcds_customer.native.zst date_dim:tpcds_date_dim.native.zst household_demographics:tpcds_household_demographics.native.zst income_band:tpcds_income_band.native.zst inventory:tpcds_inventory.native.zst item:tpcds_item.native.zst promotion:tpcds_promotion.native.zst reason:tpcds_reason.native.zst ship_mode:tpcds_ship_mode.native.zst store_returns:tpcds_store_returns.native.zst store_sales:tpcds_store_sales.native.zst store:tpcds_store.native.zst time_dim:tpcds_time_dim.native.zst warehouse:tpcds_warehouse.native.zst web_page:tpcds_web_page.native.zst web_returns:tpcds_web_returns.native.zst web_sales:tpcds_web_sales.native.zst web_site:tpcds_web_site.native.zst"
    [coffeeshop]="fact_sales:coffeeshop_fact_sales.native.zst dim_locations:coffeeshop_dim_locations.native.zst dim_products:coffeeshop_dim_products.native.zst"
    [ontime]="ontime:ontime.native.zst"
    [uk]="uk_price_paid:uk_price_paid.native.zst"
    [job]="aka_name:job_aka_name.native.zst aka_title:job_aka_title.native.zst cast_info:job_cast_info.native.zst char_name:job_char_name.native.zst comp_cast_type:job_comp_cast_type.native.zst company_name:job_company_name.native.zst company_type:job_company_type.native.zst complete_cast:job_complete_cast.native.zst info_type:job_info_type.native.zst keyword:job_keyword.native.zst kind_type:job_kind_type.native.zst link_type:job_link_type.native.zst movie_companies:job_movie_companies.native.zst movie_info:job_movie_info.native.zst movie_info_idx:job_movie_info_idx.native.zst movie_keyword:job_movie_keyword.native.zst movie_link:job_movie_link.native.zst name:job_name.native.zst person_info:job_person_info.native.zst role_type:job_role_type.native.zst title:job_title.native.zst"
)
# Query files are run (and reported) in this fixed order. Each dataset loads
# into its own database (named after the dataset) so same-named tables (TPC-H
# and TPC-DS both have `customer`) don't collide.
QUERY_ORDER="mgbench ssb hits tpch tpcds coffeeshop ontime uk job taxi"

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
# CH_TIMEOUT (seconds), when set, wraps the client in `timeout` so a hung/slow
# query is killed after that long (the connection drop makes the server cancel
# it). Version-agnostic — no reliance on server-side settings that old builds
# may lack. Left empty for load/probe/version calls.
exec_client()    { sudo ${CH_TIMEOUT:+timeout ${CH_TIMEOUT}} docker exec -i -e HOME=/tmp -e TZ=UTC "${CONTAINER}" clickhouse client "$@"; }
sidecar_client() { sudo ${CH_TIMEOUT:+timeout ${CH_TIMEOUT}} docker run --rm -i -e HOME=/tmp -e TZ=UTC \
                       -v /usr/share/zoneinfo:/usr/share/zoneinfo:ro \
                       --network "container:${CONTAINER}" "${CLIENT_IMAGE}" "$@"; }
client() {
    case "${CLIENT_MODE}" in
        sidecar) sidecar_client "$@" ;;
        *)       exec_client "$@" ;;
    esac
}

# Versions with no published image (clickhouse-built:*) are compiled from source
# on the fly here, so the benchmark is self-contained (nothing is pulled from a
# registry). The build recipe is looked up by version: tagged / bare-number
# releases from build-from-source/versions.txt (Dockerfile.ubuntu1604), and the
# untagged monthly snapshots from build-from-source/monthly.tsv (reconstructed
# via Dockerfile.reconstruct).
ensure_built_image() {
    sudo docker image inspect "${IMAGE}" >/dev/null 2>&1 && return 0
    local bfs="${HERE}/build-from-source" rec tag gcc sha
    rec="$(awk -F'\t' -v v="${VERSION}" '$1==v{print; exit}' "${bfs}/versions.txt" 2>/dev/null)"
    if [ -n "${rec}" ]; then
        tag="$(cut -f2 <<<"${rec}")"; gcc="$(cut -f4 <<<"${rec}")"
        echo "building ${IMAGE} from source (tag ${tag:-v${VERSION}-stable}, gcc-${gcc:-5})" >&2
        bash "${bfs}/build.sh" "${VERSION}" "${tag:-v${VERSION}-stable}" "${gcc:-5}" >&2
        return $?
    fi
    sha="$(awk -F'\t' -v v="${VERSION}" '$1==v{print $2; exit}' "${bfs}/monthly.tsv" 2>/dev/null)"
    if [ -n "${sha}" ]; then
        echo "reconstructing ${IMAGE} from source (commit ${sha})" >&2
        sudo docker buildx build --progress=plain --load --build-arg "TAG=${sha}" \
            -t "${IMAGE}" -f "${bfs}/Dockerfile.reconstruct" "${bfs}" >&2
        return $?
    fi
    echo "no build recipe for ${VERSION} in versions.txt or monthly.tsv" >&2
    return 1
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
        if [[ "${IMAGE}" == clickhouse-built:* ]]; then
            ensure_built_image || { echo "failed to build ${IMAGE}" >&2; return 1; }
        else
            sudo docker pull "${IMAGE}" >/dev/null 2>&1
        fi
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

# Load one dataset: create its database and (create+load) each of its tables.
# Tables that fail to create/load are left absent so their queries report null.
load_one_dataset() {
    local ds="$1" pair table file ddl t0 reader
    # Each dataset lives in its own database so same-named tables (e.g. TPC-H
    # and TPC-DS `customer`) don't clash.
    client --query "CREATE DATABASE IF NOT EXISTS ${ds}" </dev/null 2>/dev/null
    for pair in ${TABLES[$ds]}; do
        table="${pair%%:*}"; file="${pair##*:}"
        [ -f "${DATA}/${file}" ] || { echo "SKIP ${ds}.${table}: ${file} not present"; continue; }
        ddl="$("${HERE}/create/create.sh" "${VERSION}" "${ds}" "${table}")"
        echo "=== CREATE ${ds}.${table} on ${VERSION} ==="
        echo "${ddl}"
        if ! printf '%s' "${ddl}" | client --database "${ds}" --multiquery; then
            echo "CREATE ${ds}.${table} FAILED on ${VERSION}"; continue
        fi
        echo "=== INSERT INTO ${ds}.${table} FORMAT Native  <-  ${file} ($(du -h "${DATA}/${file}" | cut -f1)) ==="
        # Stream the compressed file through pv (progress %/rate/ETA once a
        # second, based on the known file size) -> zstd -dc -> a plain Native
        # INSERT, so the ancient clickhouse-client never sees compression.
        if command -v pv >/dev/null 2>&1; then
            reader=(pv -f -i 1 -N "${ds}.${table}" -- "${DATA}/${file}")
        else
            reader=(cat -- "${DATA}/${file}")
        fi
        t0=${SECONDS}
        if "${reader[@]}" | zstd -dc | client --database "${ds}" --query "INSERT INTO ${table} FORMAT Native"; then
            echo "loaded ${ds}.${table}: $(client --database "${ds}" --query "SELECT count() FROM ${table}" 2>/dev/null) rows in $((SECONDS - t0))s"
        else
            # An aborted INSERT (crash, OOM, disk full, interrupted stream) can leave
            # a partially-loaded table. Drop it so its queries report null rather than
            # timing against incomplete data.
            echo "LOAD ${ds}.${table} FAILED on ${VERSION}; dropping the incomplete table"
            client --database "${ds}" --query "DROP TABLE IF EXISTS ${table}" </dev/null 2>/dev/null
        fi
    done
}

# Load all datasets in parallel: each dataset (database + its tables) loads in
# its own background job, so the many INSERTs run concurrently against the
# server. Per-table pv progress lines interleave but stay labelled ds.table.
load_data() {
    local ds pids=()
    for ds in ${LOAD_DATASETS}; do
        load_one_dataset "${ds}" &
        pids+=("$!")
    done
    wait "${pids[@]}"
    echo "=== all dataset loads finished ==="
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

# Report on-disk size per table: via system.parts, or (for old versions without
# it) by measuring the data directory inside the container, following symlinks.
report_sizes() {
    echo "=== table sizes on disk (${VERSION}) ==="
    local out
    # The benchmark tables live in per-dataset databases; exclude the server's
    # own system databases.
    out=$(client --query "SELECT database, table, sum(bytes_on_disk) AS size FROM system.parts WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') GROUP BY database, table ORDER BY database, table FORMAT TabSeparated" </dev/null 2>/dev/null)
    if [ -n "${out}" ]; then
        printf '%s\n' "${out}"
    else
        echo "(system.parts unavailable — measuring the data directory)"
        sudo docker exec "${CONTAINER}" sh -c '
            base=/var/lib/clickhouse; [ -d "$base/data" ] || base=/opt/clickhouse
            du -sLb "$base"/data/*/* 2>/dev/null | grep -vE "/data/system/" | sort -k2' 2>/dev/null \
            || echo "(could not measure data directory)"
    fi
}

# Run one query TRIES times, print a JSON array "[t1, ..., tN]" (null on error).
# The remaining tries are skipped (recorded null) once a try either:
#   * exceeds QUERY_TIMEOUT (default 100s) — no point re-timing a too-slow query, or
#   * crashes the server (e.g. OOM kill) — the server is revived so later queries
#     still run, but this query's remaining tries are abandoned.
# A plain error while the server stays up (e.g. a feature an old version lacks)
# just records null for that try and keeps going (every try will null anyway).
run_query() {
    local query="$1" i res rc out="[" skip_rest=0
    for i in $(seq 1 "${TRIES}"); do
        if [ "${skip_rest}" = 1 ]; then
            res="null"                     # an earlier try timed out or crashed; skip the rest
        else
            CH_TIMEOUT="${QUERY_TIMEOUT:-100}"
            res=$(printf '%s' "${query}" | client --database "${QDB:-default}" --time --max_memory_usage="${MEM}" --format=Null 2>&1)
            rc=$?
            CH_TIMEOUT=""
            if [ "${rc}" = 124 ] || [ "${rc}" = 137 ]; then     # `timeout` killed it
                echo "${VERSION}: query exceeded ${QUERY_TIMEOUT:-100}s; recording null and skipping remaining tries" >&2
                skip_rest=1; res="null"
            elif [[ "${res}" =~ ^[0-9]+\.[0-9]+$ ]]; then
                :                                               # good timing
            elif ! server_alive; then
                echo "${VERSION}: server died mid-query (likely OOM); reviving and skipping remaining tries" >&2
                revive_server || true                           # restore it for the following queries
                skip_rest=1; res="null"
            else
                res="null"                                      # query errored but server is up
            fi
        fi
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
    local ACTUAL ds query FIRST=1 qnum=0 row QDB
    ACTUAL=$(client --query "SELECT version()" 2>/dev/null | tr -d '\r')
    echo "benchmarking ${VERSION} (server reports ${ACTUAL})" >&2
    {
        echo '{'
        echo "    \"version\": \"${VERSION}\","
        echo "    \"actual_version\": \"${ACTUAL}\","
        echo '    "result":'
        echo '    ['
        for ds in ${QUERY_ORDER}; do
            QDB="${ds}"   # run this dataset's queries with its database as default
            # Read queries on FD 3 (not stdin) so the per-query `docker exec/run -i`
            # client calls can't consume the query file.
            while IFS= read -r query <&3; do
                [ -z "${query}" ] && continue
                query="${query%;}"                       # strip trailing semicolon
                drop_caches
                qnum=$((qnum + 1))
                row="$(run_query "${query}")"
                echo "q${qnum} [${ds}]: ${row}" >&2      # live timings to the log
                [ "${FIRST}" = 0 ] && echo ','
                FIRST=0
                printf '%s' "${row}"
            done 3< "${HERE}/queries/${ds}.sql"
        done
        echo
        echo '    ]'
        echo '}'
    } > "${OUT}"
    echo "wrote ${OUT}; result:" >&2
    cat "${OUT}"                                          # emit the JSON so it is captured/received
    report_sizes
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
