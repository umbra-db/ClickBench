#!/usr/bin/env bash
# Build the untagged monthly snapshots (monthly.tsv) from source, newest to
# oldest, via Dockerfile.reconstruct (see reconstruct.sh). Each snapshot becomes
# image clickhouse-built:<YYYY-MM-DD>. Snapshots at/after 2016-03 have a public
# build system; earlier ones are reconstructed by transplanting the 2016-03
# donor's build system + contrib. Going far enough back the transplant stops
# matching the source - that boundary is what this sweep discovers.
#
#   ./build-monthly.sh                 # all months in monthly.tsv (newest first)
#   ./build-monthly.sh 2016-02-01 ...  # only the given months
#   JOBS=3 ./build-monthly.sh          # 3 concurrent builds (default 3)
#
# monthly.tsv is "<YYYY-MM-DD><TAB><commit-sha><TAB><commit-date>" per line.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGS="${HERE}/logs"; mkdir -p "${LOGS}"
JOBS="${JOBS:-3}"

declare -A WANT=()
for a in "$@"; do WANT["$a"]=1; done

build_one() {  # date sha
    local date="$1" sha="$2"
    if sudo docker image inspect "clickhouse-built:${date}" >/dev/null 2>&1; then
        echo "skip ${date}: image exists"; return 0
    fi
    if sudo docker buildx build --progress=plain --load \
            --build-arg "TAG=${sha}" --build-arg "GCC=${GCC:-5}" \
            -t "clickhouse-built:${date}" -f "${HERE}/Dockerfile.reconstruct" "${HERE}" \
            >"${LOGS}/reconstruct-${date}.log" 2>&1; then
        # smoke test: server boots and answers a query
        sudo docker rm -f "smoke-${date}" >/dev/null 2>&1
        sudo docker run -d --name "smoke-${date}" "clickhouse-built:${date}" >/dev/null 2>&1
        local v="" i
        for i in $(seq 1 30); do
            v=$(sudo docker exec "smoke-${date}" clickhouse client --query "SELECT version()" 2>/dev/null) && break
            sleep 1
        done
        sudo docker rm -f "smoke-${date}" >/dev/null 2>&1
        if [ -n "${v}" ]; then echo "OK ${date} (version ${v})"; else echo "BUILT-BUT-NO-BOOT ${date}" >&2; fi
    else
        echo "FAILED ${date} (see ${LOGS}/reconstruct-${date}.log)" >&2
    fi
}

# newest first (monthly.tsv is already newest->oldest)
while IFS=$'\t' read -r date sha _cd; do
    [ -z "${date}" ] && continue
    [ "$#" -gt 0 ] && [ -z "${WANT[$date]:-}" ] && continue
    while [ "$(jobs -rp | wc -l)" -ge "${JOBS}" ]; do wait -n 2>/dev/null || sleep 5; done
    build_one "${date}" "${sha}" &
done < "${HERE}/monthly.tsv"
wait
echo "build-monthly done"
