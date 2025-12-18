#!/bin/bash

TRIES=3

query_count=0
cat queries.sql | while read -r query; do
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches
    if [ "$LOCAL" -eq 1 ]; then
        $SERVER db/umbra.db &>> server.log &
        PID=$!
    else
        docker restart $(docker ps -a -q)
    fi

    retry_count=0
    while [ $retry_count -lt 120 ]; do
        if PGPASSWORD=postgres psql -p 5432 -h 127.0.0.1 -U postgres -c "SELECT 'Ok';" 2> /dev/null; then
            break
        fi

        retry_count=$((retry_count+1))
        sleep 1
    done

    echo "$query";
    for i in $(seq 1 $TRIES); do
        PGPASSWORD=postgres psql -p 5432 -h 127.0.0.1 -U postgres -t -c '\timing' -c "$query" 2>&1 | grep -P 'Time|psql: error' | tail -n1
    done

    if [ "$TRACE" -eq 1 ]; then
        PGPASSWORD=postgres psql -p 5432 -h 127.0.0.1 -U postgres -c "SET debug.perftracer.dump = 'traces/${MACHINE}.${VERSION}/${query_count}.trace';"
    fi

    if [ "$LOCAL" -eq 1 ]; then
        kill $PID
        wait $PID
    fi

    query_count=$((query_count+1))
done
