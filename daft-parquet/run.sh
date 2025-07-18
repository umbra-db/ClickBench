#!/bin/bash

machine_name=${1}
mode=${2}
full_machine="${1}"

TRIES=3
QUERY_COUNT=43
RESULT_FILE="results/${machine_name}.${mode}.json"
FILE_SIZE=$(wc -c < hits.parquet | awk '{print $1}')

declare -a results=()
for ((i=0; i<QUERY_COUNT; i++)); do
    nulls=$(printf 'null%.0s' $(seq 1 $TRIES))
    results[i]="[${nulls// /,}]"
done

mkdir -p results

for ((q=1; q<=QUERY_COUNT; q++)); do
    echo "Processing query $q..."

    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

    output=$(python3 query.py $q $mode 2>&1)
    IFS=',' read -r t1 t2 t3 <<< "$(echo "$output" | tail -1)"

    results[$((q-1))]="[${t1:-null},${t2:-null},${t3:-null}]"
done

echo '{
    "system": "Daft",
    "date": "'$(date +%Y-%m-%d)'",
    "machine": "'$full_machine'",
    "cluster_size": 1,
    "comment": "",
    "tags": [
        "Rust",
        "stateless",
        "serverless",
        "embedded"
    ],
    "load_time": 0,
    "data_size": '$FILE_SIZE',
    "result": [
'"$(IFS=,; printf '%s,\n' "${results[@]}" | sed '$s/,$//')"'
    ]
}' > $RESULT_FILE

echo "Benchmark completed. Results saved to $RESULT_FILE"
