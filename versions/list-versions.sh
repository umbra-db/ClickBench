#!/usr/bin/env bash
# List the ClickHouse versions to benchmark, one per line, as:
#
#     <version>\t<image_ref>\t<release_date>
#
# The authoritative set of releases comes from ClickHouse's own
# version_date.tsv (oldest is 1.1.54011, 2016-08-18). Selection rules:
#   * keep ALL versions of the 1.1.x family;
#   * for calendar-versioned releases (18.x and newer), keep only the
#     latest patch within every major.minor (one per YY.MM line).
#
# Each selected version is resolved to a provider:
#   * yandex/clickhouse-server:<v>      historical images (1.1.x .. 21.x)
#   * clickhouse/clickhouse-server:<v>  modern images (20.x .. today)
#   * package                           no image, but a .deb/.tgz may exist
#                                        (runner installs it into Ubuntu)
#   * unavailable                       neither image nor package published
#                                        (e.g. the pre-1.1.54019 builds)
# We prefer the yandex image while it exists (<= 21.x) and clickhouse otherwise.
#
# The version_date.tsv and Docker tag lists are cached under prepare-data/data/.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="${HERE}/prepare-data/data"
mkdir -p "${CACHE}"

# --- authoritative release list (version + date) -------------------------------
VD="${CACHE}/version_date.tsv"
[ -s "${VD}" ] || curl -s "https://clickhouse.com/data/version_date.tsv" -o "${VD}"

# --- Docker tag lists for provider resolution ----------------------------------
fetch_tags() {
    local repo="$1" out="$2"
    [ -s "${out}" ] && return 0
    local token
    token=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${repo}:pull" \
        | grep -oE '"token":"[^"]+"' | sed 's/"token":"//;s/"//')
    curl -s -H "Authorization: Bearer ${token}" \
        "https://registry-1.docker.io/v2/${repo}/tags/list" \
        | tr ',' '\n' | grep -oE '"[^"]+"' | tr -d '"' > "${out}"
}
fetch_tags "yandex/clickhouse-server"     "${CACHE}/tags-yandex.txt"
fetch_tags "clickhouse/clickhouse-server" "${CACHE}/tags-clickhouse.txt"
YANDEX=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$' "${CACHE}/tags-yandex.txt"     | sort -uV)
CLICKHOUSE=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$' "${CACHE}/tags-clickhouse.txt" | sort -uV)
has() { grep -qxF "$2" <<<"$1"; }

# Resolve an image for a version. version_date uses 4-component builds (19.1.16.79)
# while old images are often tagged with 3 (19.1.16), so fall back to the newest
# tag sharing the first three components. Echoes the image ref, or "" if none.
resolve_image() {
    local v="$1" major="${v%%.*}" v3 cand
    if [ "${major}" -le 21 ] 2>/dev/null && has "${YANDEX}" "${v}"; then
        echo "yandex/clickhouse-server:${v}"; return
    fi
    has "${CLICKHOUSE}" "${v}" && { echo "clickhouse/clickhouse-server:${v}"; return; }
    has "${YANDEX}"     "${v}" && { echo "yandex/clickhouse-server:${v}";     return; }
    v3="$(cut -d. -f1-3 <<<"${v}")"
    if [ "${major}" -le 21 ] 2>/dev/null; then
        cand=$(grep -E "^${v3//./\\.}(\.|$)" <<<"${YANDEX}" | tail -1)
        [ -n "${cand}" ] && { echo "yandex/clickhouse-server:${cand}"; return; }
    fi
    cand=$(grep -E "^${v3//./\\.}(\.|$)" <<<"${CLICKHOUSE}" | tail -1)
    [ -n "${cand}" ] && { echo "clickhouse/clickhouse-server:${cand}"; return; }
    echo ""
}

# --- normalise version_date.tsv to "version<TAB>date", version-sorted ----------
NORM=$(sed -E 's/^v//; s/-(stable|lts|testing|prestable)\t/\t/' "${VD}" \
       | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' | sort -V)

emit() {  # version date  -> resolve provider and print the line
    local v="$1" date="$2" image
    image="$(resolve_image "${v}")"
    if [ -z "${image}" ]; then
        # No image. packages.clickhouse.com ships .tgz from 21.1 on; older = gone.
        [ "${v%%.*}" -ge 21 ] 2>/dev/null && image="package" || image="unavailable"
    fi
    printf '%s\t%s\t%s\n' "${v}" "${image}" "${date}"
}

{
    # All 1.1.x are kept (including the handful with no image, so they are at
    # least listed/"found").
    grep -E $'^1\\.1\\.' <<<"${NORM}" | while IFS=$'\t' read -r v date; do
        emit "${v}" "${date}"
    done

    # Calendar releases: per major.minor, take the latest patch that resolves to
    # an actual image (falling back to an older patch in the same line if the
    # newest build has no image).
    grep -vE $'^1\\.1\\.' <<<"${NORM}" \
        | awk -F'\t' '{split($1,p,"."); print p[1]"."p[2]}' | sort -uV | while read -r key; do
        chosen=""
        while IFS=$'\t' read -r v date; do
            [ -n "$(resolve_image "${v}")" ] && { emit "${v}" "${date}"; chosen=1; break; }
            newest_v="${v}"; newest_d="${date}"
        done < <(awk -F'\t' -v k="${key}" '{split($1,p,"."); if (p[1]"."p[2]==k) print}' <<<"${NORM}" | sort -rV)
        if [ -z "${chosen}" ]; then emit "${newest_v}" "${newest_d}"; fi   # none runnable -> newest as unavailable
    done
} | sort -V
