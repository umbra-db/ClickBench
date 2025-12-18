#!/bin/bash

VERSION=${VERSION:-latest}
MACHINE=${MACHINE:-$(hostname)}
LOCAL=${LOCAL:-0}
TRACE=${TRACE:-0}

if [ ! -f data/hits.tsv ]; then
    # Ubuntu
    sudo apt-get update -y
    sudo apt-get install -y docker.io postgresql-client gzip

    # Amazon Linux
    # yum install nc postgresql15

    # Download + uncompress hits
    rm -rf data
    mkdir data
    sudo apt-get install -y pigz
    wget --continue --progress=dot:giga 'https://datasets.clickhouse.com/hits_compatible/hits.tsv.gz'
    pigz -d -f hits.tsv.gz
    mv hits.tsv data
    chmod 777 -R data
fi

# I spend too much time here battling cryptic error messages only to find out that the data needs to be in some separate directory
rm -rf db
mkdir db
chmod 777 -R db

SQL=""
SERVER=""
if [ "$TRACE" -eq 1 ]; then
    SQL=./bin/trace/sql
    SERVER=./bin/trace/server
    LOCAL=1
elif [ "$LOCAL" -eq 1 ]; then
    SQL=./bin/sql
    SERVER=./bin/server
fi

# https://hub.docker.com/r/umbradb/umbra
if [ "$LOCAL" -eq 1 ]; then
    $SQL -createdb db/umbra.db <<<"ALTER ROLE postgres WITH LOGIN SUPERUSER PASSWORD 'postgres';" || exit 1
    $SERVER db/umbra.db &> server.log &
    PID=$!
else
    docker run -d -v ./db:/var/db -v ./data:/data -p 5432:5432 --ulimit nofile=1048576:1048576 --ulimit memlock=8388608:8388608 umbradb/umbra:${VERSION}
fi

retry_count=0
while [ $retry_count -lt 120 ]; do
    if PGPASSWORD=postgres psql -p 5432 -h 127.0.0.1 -U postgres -c "SELECT 'Ok';" &> /dev/null; then
        break
    fi

    retry_count=$((retry_count+1))
    sleep 1
done

# choose create file depending on local vs docker
CREATE_FILE=create.sql
if [ "$LOCAL" -eq 1 ]; then
    CREATE_FILE=create_local.sql
fi
start=$(date +%s%3N)
PGPASSWORD=postgres psql -p 5432 -h 127.0.0.1 -U postgres -f ${CREATE_FILE} 2>&1 | tee load_out.txt
end=$(date +%s%3N)
if [ "$TRACE" -eq 1 ]; then
    mkdir -p "traces/${MACHINE}.${VERSION}"
    PGPASSWORD=postgres psql -p 5432 -h 127.0.0.1 -U postgres -c "SET debug.perftracer.dump = 'traces/${MACHINE}.${VERSION}/load.trace';"
fi

if [ "$LOCAL" -eq 1 ]; then
    kill $PID
    wait $PID
fi

if grep 'ERROR' load_out.txt
then
    exit 1
fi

export SERVER
export VERSION
export MACHINE
export LOCAL
export TRACE
./run.sh 2>&1 | tee log.txt

# Calculate persistence size
sudo chmod 777 -R db # otherwise 'du' complains about permission denied

load_ms=$(( end - start ))
load_time=$(awk -v ms="$load_ms" 'BEGIN{printf "%.3f", ms/1000}')
data_size=$(du -bcs db | awk '/total$/ {print $1}')

echo "Load time: $load_time"
echo -n "Data size: $data_size"

# Pretty-printing
cat log.txt | grep -oP 'Time: \d+\.\d+ ms|psql: error' | sed -r -e 's/Time: ([0-9]+\.[0-9]+) ms/\1/; s/^.*psql: error.*$/null/' |
    awk '{ if (i % 3 == 0) { printf "[" }; if ($1 == "null") { printf $1 } else { printf $1 / 1000 }; if (i % 3 != 2) { printf "," } else { print "]," }; ++i; }'

# Cleanup
if [ "$LOCAL" -eq 0 ]; then
    docker stop $(docker ps -a -q) && docker rm $(docker ps -a -q) && docker volume prune --all --force
fi

# Build JSON result file
result_elems=$(cat log.txt | grep -oP 'Time: \d+\.\d+ ms|psql: error' \
  | sed -r -e 's/Time: ([0-9]+\.[0-9]+) ms/\1/; s/^.*psql: error.*$/null/' \
  | awk '{ if (i % 3 == 0) { printf "[" }; if ($1 == "null") { printf $1 } else { printf "%.6f", $1 / 1000 }; if (i % 3 != 2) { printf "," } else { print "]," }; ++i; }')

result_json=$(printf "%s\n" "$result_elems" \
  | sed '$ s/],$/]/' \
  | awk 'BEGIN{print "["} {printf "    %s\n", $0} END{print "  ]"}')


COMMENT=""
NAME="${MACHINE}.${VERSION}"
if [ "$TRACE" -eq 1 ]; then
    COMMENT=" (trace)"
    NAME="${NAME}.trace"
elif [ "$LOCAL" -eq 1 ]; then
    COMMENT=" (local)"
    NAME="${NAME}.local"
fi

cat > results/${NAME}.json <<JSON
{
  "system": "Umbra ${VERSION}${COMMENT}",
  "date": "$(date +%F)",
  "machine": "${MACHINE}",
  "cluster_size": 1,
  "proprietary": "yes",
  "hardware": "cpu",
  "tuned": "no",
  "tags": ["C++", "column-oriented", "PostgreSQL compatible"],
  "load_time": ${load_time},
  "data_size": ${data_size},
  "result": ${result_json}
}
JSON

echo "Wrote results/${MACHINE}.${VERSION}.json"