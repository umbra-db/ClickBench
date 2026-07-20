#!/bin/bash
# Smoke-test ZigHouse's SQL engine on a handful of non-ClickBench statements
# through the ClickHouse-compatible HTTP interface. This runs automatically at
# the end of ./load (so the capability frontier is exercised on every run) and
# can also be invoked standalone from this directory once the server is up and
# the dataset has been loaded.
set -u

: "${ZIGHOUSE_PORT:=28123}"
http_port=$((ZIGHOUSE_PORT + 1))
base="http://127.0.0.1:${http_port}"

run() {
    echo "== $1 =="
    echo "SQL: $2"
    curl -sS -G "${base}/" \
        --data-urlencode "query=$2" \
        --data-urlencode "default_format=TabSeparated" \
        || echo "  -> error"
    echo
}

run "count_all"       "SELECT COUNT(*) FROM hits"
run "sum_with_filter" "SELECT SUM(AdvEngineID) FROM hits WHERE EventDate >= '2013-07-15'"
run "min_max_date"    "SELECT MIN(EventDate), MAX(EventDate) FROM hits"
run "count_distinct"  "SELECT COUNT(DISTINCT SearchEngineID) FROM hits"
run "groupby_topk"    "SELECT RegionID, COUNT(*) AS c FROM hits GROUP BY RegionID ORDER BY c DESC LIMIT 5"

exit 0
