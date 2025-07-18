#!/bin/bash

# Install

sudo apt-get update
sudo apt-get install -y python3-pip
pip install pandas duckdb==1.1.3

# Download the data
wget --continue --progress=dot:giga https://datasets.clickhouse.com/hits_compatible/athena/hits.parquet

# Run the queries

./run.sh 2>&1 | tee log.txt
