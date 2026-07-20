# ZigHouse

ZigHouse is an experimental, ClickHouse-compatible analytical database written
in Zig. It ingests data into a MergeTree-compatible on-disk store and executes
analytical SQL through a single native execution path (there is no
ClickBench-specific query handling).

This entry uses a **generic** published release binary — not a
ClickBench-specific build:

https://github.com/donge/zighouse/releases/tag/v1.0.2

`./install` downloads the Linux x86_64 release, decompresses it, and verifies
its SHA256 checksum. Override the version/checksum with the `ZIGHOUSE_VERSION`
and `ZIGHOUSE_SHA256` environment variables.

## Running

From this directory inside the ClickBench repository:

```sh
./benchmark.sh
```

The shared driver (`../lib/benchmark-common.sh`) installs the binary, starts the
server, loads the dataset, and runs the 43 ClickBench queries three times each.

## How it works

ZigHouse runs as a server that speaks the ClickHouse HTTP protocol:

- `./start` / `./stop` — launch/stop `zighouse serve`. With `--port=<P>` the
  native TCP interface listens on `<P>` and HTTP on `<P>+1` (default 28123 /
  28124).
- `./load` — creates the table (`create.sql`) and streams the dataset in over
  HTTP. The server ingests JSONEachRow (it does not read Parquet or TSV
  directly), so the ClickBench `hits.json` dataset is posted in ≤256 MiB,
  line-aligned chunks, one `INSERT ... FORMAT JSONEachRow` per chunk. After the
  load, `generic-smoke.sh` runs a few non-ClickBench statements as a sanity
  check on the generic SQL engine.
- `./query` — sends one SQL statement over HTTP and reports the wall-clock time.
- `./data-size` — size on disk of the store directory.

## Notes

The results directory holds per-machine result files produced by the shared
driver; regenerate them by running `./benchmark.sh` on the target hardware and
committing the resulting JSON under `results/YYYYMMDD/`.
