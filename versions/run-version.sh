#!/usr/bin/env bash
# Benchmark a single ClickHouse version inside Docker.
#
#   ./run-version.sh <version> [image_ref]
#
# Spins up the server, creates the six tables with version-appropriate DDL
# (create/create.sh), loads the prepared Native files with a plain
# `clickhouse-client INSERT ... FORMAT Native`, then times every query in
# queries/{mgbench,ssb,hits,taxi}.sql (TRIES runs each, dropping the page
# cache between queries) and writes results/<version>.json.
#
# image_ref comes from list-versions.sh: either "<repo>/clickhouse-server:<v>"
# or the literal "package" (install the .deb into Ubuntu — fallback provider).

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${DATA:-${HERE}/prepare-data/data}"
TRIES="${TRIES:-3}"
MEM=100000000000   # 100G per-query memory limit

VERSION="${1:?usage: run-version.sh <version> [image_ref]}"
IMAGE="${2:-}"
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
trap cleanup EXIT

# Client dispatch. Modern/most images bundle a client (`exec` mode). The oldest
# server images (1.1.54xxx, early 18.x) ship only clickhouse-server, so we drive
# them with the matching-version client image as a sidecar sharing the server's
# network namespace (`sidecar` mode) — same native protocol, precise --time.
CLIENT_IMAGE="${IMAGE/-server/-client}"
CLIENT_MODE=""   # set by start_server: exec | sidecar
exec_client()    { sudo docker exec -i "${CONTAINER}" clickhouse client "$@"; }
sidecar_client() { sudo docker run --rm -i --network "container:${CONTAINER}" "${CLIENT_IMAGE}" "$@"; }
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
    local ds pair table file
    for ds in hits ssb mgbench taxi; do
        for pair in ${TABLES[$ds]}; do
            table="${pair%%:*}"; file="${pair##*:}"
            [ -f "${DATA}/${file}" ] || { echo "missing ${file}, skipping ${table}" >&2; continue; }
            "${HERE}/create/create.sh" "${VERSION}" "${table}" \
                | client --multiquery >/dev/null 2>&1 \
                || { echo "create ${table} failed on ${VERSION}" >&2; continue; }
            # Decompress on the host and stream plain Native into the client, so
            # the (possibly ancient) clickhouse-client never sees compression.
            zstd -dc "${DATA}/${file}" | client --query "INSERT INTO ${table} FORMAT Native" >/dev/null 2>&1 \
                || echo "load ${table} failed on ${VERSION}" >&2
        done
    done
}

drop_caches() { sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1; }

# Run one query TRIES times, print a JSON array "[t1, t2, t3]" (null on error).
run_query() {
    local query="$1" i res out="["
    for i in $(seq 1 "${TRIES}"); do
        res=$(printf '%s' "${query}" | client --time --max_memory_usage="${MEM}" --format=Null 2>&1)
        if [[ "${res}" =~ ^[0-9]+\.[0-9]+$ ]]; then out+="${res}"; else out+="null"; fi
        [ "${i}" -ne "${TRIES}" ] && out+=", "
    done
    echo "${out}]"
}

# ---- run ----
start_server || exit 1
ACTUAL=$(client --query "SELECT version()" 2>/dev/null | tr -d '\r')
echo "running benchmark on ${VERSION} (server reports ${ACTUAL})" >&2
load_data

{
    echo '{'
    echo "    \"version\": \"${VERSION}\","
    echo "    \"actual_version\": \"${ACTUAL}\","
    echo '    "result":'
    echo '    ['
    FIRST=1
    for ds in ${QUERY_ORDER}; do
        while IFS= read -r query; do
            [ -z "${query}" ] && continue
            query="${query%;}"                       # strip trailing semicolon
            drop_caches
            [ "${FIRST}" = 0 ] && echo ','
            FIRST=0
            printf '%s' "$(run_query "${query}")"
        done < "${HERE}/queries/${ds}.sql"
    done
    echo
    echo '    ]'
    echo '}'
} > "${OUT}"

echo "wrote ${OUT}" >&2
