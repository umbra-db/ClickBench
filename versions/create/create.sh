#!/usr/bin/env bash
# Emit a CREATE TABLE statement for <table> tailored to ClickHouse <version>.
#
#   ./create.sh <version> <table>
#
# Tables: hits | lineorder_flat | logs1 | logs2 | logs3 | trips
#
# The same Native data files load into every version, so only the *engine*
# clause changes with the version:
#   * Modern releases use custom-partitioning syntax:
#         ENGINE = MergeTree PARTITION BY toYYYYMM(<date>) ORDER BY (<key>)
#   * The earliest 1.1.x releases (before custom partitioning landed) only
#     understand the legacy positional syntax, which needs a Date column:
#         ENGINE = MergeTree(<date>, (<key>), 8192)
# Every table therefore carries a Date column (EventDate / LO_ORDERDATE /
# pickup_date / the synthesised log_date) usable by the legacy engine.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERSION="${1:?usage: create.sh <version> <table>}"
TABLE="${2:?usage: create.sh <version> <table>}"

# Custom-partitioning (new) syntax landed in 1.1.54310; everything from 18.x
# on supports it. Older 1.1.x builds get the legacy positional engine.
new_syntax() {
    local major minor patch
    IFS=. read -r major minor patch _ <<<"$VERSION"
    if [ "$major" = "1" ] && [ "$minor" = "1" ]; then
        [ "${patch:-0}" -ge 54310 ]
    else
        [ "$major" -ge 18 ]
    fi
}

# Per-table Date column and primary key.
case "$TABLE" in
    hits)           DATE_COL=EventDate;   ORDER_KEY="CounterID, EventDate, intHash32(UserID), EventTime" ;;
    lineorder_flat) DATE_COL=LO_ORDERDATE; ORDER_KEY="LO_ORDERDATE, LO_ORDERKEY" ;;
    logs1)          DATE_COL=log_date;    ORDER_KEY="machine_group, machine_name, log_time" ;;
    logs2)          DATE_COL=log_date;    ORDER_KEY="log_time" ;;
    logs3)          DATE_COL=log_date;    ORDER_KEY="event_type, log_time" ;;
    trips)          DATE_COL=pickup_date; ORDER_KEY="pickup_datetime" ;;
    *) echo "unknown table: $TABLE" >&2; exit 1 ;;
esac

COLUMNS="$(cat "${HERE}/schema/${TABLE}.columns")"

echo "DROP TABLE IF EXISTS ${TABLE};"
if new_syntax; then
    cat <<SQL
CREATE TABLE ${TABLE}
(
${COLUMNS}
) ENGINE = MergeTree PARTITION BY toYYYYMM(${DATE_COL}) ORDER BY (${ORDER_KEY});
SQL
else
    cat <<SQL
CREATE TABLE ${TABLE}
(
${COLUMNS}
) ENGINE = MergeTree(${DATE_COL}, (${ORDER_KEY}), 8192);
SQL
fi
