#!/usr/bin/env bash
# Prepare taxi.native — the NYC taxi "trips" table (classic ClickHouse dataset).
#
# The source CSVs have 51 positional columns. We read every field as String
# (so parsing never fails across the whole dump) and cast to the oldest-
# compatible target types, synthesising pickup_date (Date) from the pickup
# timestamp for the legacy MergeTree engine. Enum columns (vendor_id,
# payment_type, cab_type) are downgraded to String.
#
# TAXI_GLOB selects the source files: a single file for a quick slice, or
# trips_*.csv.gz (default) for the full ~1.3B-row dataset.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLICKHOUSE="${CLICKHOUSE:-$HOME/clickhouse}"
OUT="${HERE}/data/taxi.native.zst"
GLOB="${TAXI_GLOB:-trips_*.csv.gz}"
SRC="https://clickhouse-datasets.s3.amazonaws.com/taxi/csv/${GLOB}"

# 51 positional String columns.
STRUCT="$(for i in $(seq 1 51); do printf 'c%d String, ' "$i"; done | sed 's/, $//')"

echo "taxi: building trips from ${GLOB} -> ${OUT}"
"${CLICKHOUSE}" local --max_memory_usage 0 \
    --query "
SELECT
    toDate(parseDateTimeBestEffortOrZero(c3))      AS pickup_date,
    toUInt32OrZero(c1)                             AS trip_id,
    c2                                             AS vendor_id,
    parseDateTimeBestEffortOrZero(c3)              AS pickup_datetime,
    parseDateTimeBestEffortOrZero(c4)              AS dropoff_datetime,
    c5                                             AS store_and_fwd_flag,
    toUInt8OrZero(c6)                              AS rate_code_id,
    toFloat64OrZero(c7)                            AS pickup_longitude,
    toFloat64OrZero(c8)                            AS pickup_latitude,
    toFloat64OrZero(c9)                            AS dropoff_longitude,
    toFloat64OrZero(c10)                           AS dropoff_latitude,
    toUInt8OrZero(c11)                             AS passenger_count,
    toFloat64OrZero(c12)                           AS trip_distance,
    toFloat32OrZero(c13)                           AS fare_amount,
    toFloat32OrZero(c14)                           AS extra,
    toFloat32OrZero(c15)                           AS mta_tax,
    toFloat32OrZero(c16)                           AS tip_amount,
    toFloat32OrZero(c17)                           AS tolls_amount,
    toFloat32OrZero(c18)                           AS ehail_fee,
    toFloat32OrZero(c19)                           AS improvement_surcharge,
    toFloat32OrZero(c20)                           AS total_amount,
    c21                                            AS payment_type,
    toUInt8OrZero(c22)                             AS trip_type,
    c23                                            AS pickup,
    c24                                            AS dropoff,
    c25                                            AS cab_type,
    toFloat32OrZero(c26)                           AS precipitation,
    toFloat32OrZero(c27)                           AS snow_depth,
    toFloat32OrZero(c28)                           AS snowfall,
    toFloat32OrZero(c29)                           AS max_temperature,
    toFloat32OrZero(c30)                           AS min_temperature,
    toFloat32OrZero(c31)                           AS average_wind_speed,
    toInt32OrZero(c32)                             AS pickup_nyct2010_gid,
    c33                                            AS pickup_ctlabel,
    toInt32OrZero(c34)                             AS pickup_borocode,
    c35                                            AS pickup_boroname,
    c36                                            AS pickup_ct2010,
    c37                                            AS pickup_boroct2010,
    c38                                            AS pickup_cdeligibil,
    c39                                            AS pickup_ntacode,
    c40                                            AS pickup_ntaname,
    toInt32OrZero(c41)                             AS pickup_puma,
    toInt32OrZero(c42)                             AS dropoff_nyct2010_gid,
    c43                                            AS dropoff_ctlabel,
    toInt32OrZero(c44)                             AS dropoff_borocode,
    c45                                            AS dropoff_boroname,
    c46                                            AS dropoff_ct2010,
    c47                                            AS dropoff_boroct2010,
    c48                                            AS dropoff_cdeligibil,
    c49                                            AS dropoff_ntacode,
    c50                                            AS dropoff_ntaname,
    toInt32OrZero(c51)                             AS dropoff_puma
FROM s3('${SRC}', 'CSV', '${STRUCT}')
FORMAT Native" | zstd -q -6 -T0 -c > "${OUT}"
ls -l "${OUT}"
