#!/bin/bash -e

# Fetch the latest Versions Benchmark result for every version from the sink database
# (sink.data, rows with kind = "versions-benchmark", sent by cloud-init.sh.in) and write
# results/<version>.json, enriched with the release date. The committed result files are
# produced solely by this script -- do not edit them by hand.
#
# Connection settings come from $CONNECTION_PARAMS, as in the repo's collect-results.sh:
#   CONNECTION_PARAMS='--user check_benchmark_results --password *** --host play.clickhouse.com --secure' \
#       ./fetch-results.sh
#
# Then regenerate the page data with ./generate-results.sh.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${HERE}"
CH() { clickhouse-client ${CONNECTION_PARAMS} "$@"; }

mkdir -p results

# Release-date lookup. list-versions.sh resolves it (column 3) for published and tagged
# builds from the authoritative version_date.tsv; the reconstructed monthly snapshots are
# not in that list, so fall back to their commit date in build-from-source/monthly.tsv.
LV="$(./list-versions.sh 2>/dev/null || true)"
reldate() {
    local v="$1" d
    d="$(awk -F'\t' -v v="$v" '$1==v{print $3; exit}' <<<"${LV}")"
    [ -z "${d}" ] && d="$(awk -F'\t' -v v="$v" '$1==v{print $3; exit}' build-from-source/monthly.tsv 2>/dev/null)"
    printf '%s' "${d}"
}

mapfile -t VERSIONS < <(CH --query "
    SELECT DISTINCT JSONExtractString(content, 'version') AS v
    FROM sink.data
    WHERE JSONExtractString(content, 'kind') = 'versions-benchmark' AND v != ''
      AND length(JSONExtractArrayRaw(content, 'result')) = 344
    ORDER BY v
    FORMAT TSV")

echo "fetching ${#VERSIONS[@]} versions from the sink" >&2
rm -f results/*.json
for v in "${VERSIONS[@]}"; do
    [ -z "${v}" ] && continue
    # argMax over time keeps the most recent run for this version.
    CH --query "
        SELECT argMax(content, time) FROM sink.data
        WHERE JSONExtractString(content, 'kind') = 'versions-benchmark'
          AND JSONExtractString(content, 'version') = '${v}'
          AND length(JSONExtractArrayRaw(content, 'result')) = 344
        FORMAT TSVRaw" > /tmp/vb-content.json
    rd="$(reldate "${v}")"
    # Keep the recorded fields; add release_date (preferring one already in the payload).
    # Compact one line per file: these are generated artifacts, kept small in git.
    jq -cS --arg rd "${rd}" \
        '. + {release_date: (.release_date // (if $rd == "" then null else $rd end))}' \
        /tmp/vb-content.json > "results/${v}.json"
    echo "  results/${v}.json (released ${rd:-unknown})" >&2
done
echo "wrote $(ls results/*.json 2>/dev/null | wc -l) result files" >&2
