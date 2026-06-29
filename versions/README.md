# ClickHouse Versions Benchmark

This benchmark runs the **same** workload on the **same** data across every
historical and current ClickHouse version, to show how performance has evolved
over the years. It is published at https://benchmark.clickhouse.com/versions/
and described in the blog post
[ClickHouse Over the Years with Benchmarks](https://clickhouse.com/blog/clickhouse-over-the-years-with-benchmarks).

Please don't confuse it with the per-commit ClickHouse Performance Test, described
[here](https://clickhouse.com/blog/testing-the-performance-of-click-house).

## How it works

Every ClickHouse release is published as a Docker image, so each version is run
in its own container — from `1.1.54xxx` (2018) to today — with no host install.

1. **`list-versions.sh`** — selects the versions to test and resolves an image
   for each. Rules: keep **all** of the `1.1.x` family; for calendar-versioned
   releases (18.x+) keep only the **latest patch within each major.minor**.
   Historical images come from `yandex/clickhouse-server`; modern ones from
   `clickhouse/clickhouse-server`. A version with no image falls back to
   installing the `.deb`/`.tgz` from packages.clickhouse.com into Ubuntu.

2. **`prepare-data/prepare.sh`** — builds the canonical data files once, in the
   **Native** format, using only the oldest-compatible types so a single set of
   files loads into *every* version (validated against `1.1.54378`):
   - `hits.native` — ClickBench `hits` (100M rows, 105 columns).
   - `ssb.native` — Star Schema Benchmark `lineorder_flat` (scale factor 100).
   - `mgbench{1,2,3}.native` — Brown benchmark `logs1`/`logs2`/`logs3`.
   - `taxi.native` — NYC `trips`.

   Type downgrades: `LowCardinality`→`String`, `IPv4`→`String`,
   `DateTime64`→`DateTime`, enums→`String`; `Nullable` is kept only where the
   query set needs `IS NULL` (mgbench `logs1`). Tables without a natural date
   carry a synthesised `log_date Date` so the legacy `MergeTree` engine works.

3. **`create/create.sh <version> <table>`** — emits version-appropriate DDL.
   Modern releases use `ENGINE = MergeTree PARTITION BY … ORDER BY …`; the
   earliest `1.1.x` (before custom partitioning, < `1.1.54310`) use the legacy
   positional `ENGINE = MergeTree(date, (key), 8192)`. Column lists live in
   `create/schema/*.columns`.

4. **`run-version.sh <version> [image]`** — starts the server, creates the
   tables, loads each Native file with the simplest possible
   `clickhouse-client INSERT … FORMAT Native`, then times every query in
   `queries/{mgbench,ssb,hits,taxi}.sql` (`TRIES` runs each, dropping the page
   cache between queries) and writes `results/<version>.json`.

5. **`run-all.sh`** — runs `run-version.sh` for every selected version.

6. **`generate-results.sh`** — folds `results/*.json` into `index.html`.

## Usage

```bash
# 1. Prepare the data once (full scale — reproduces the original benchmark).
#    For a quick smoke test use a slice:
#      HITS_PARTS=0 SSB_SCALE=1 TAXI_GLOB=trips_xaa.csv.gz ./prepare-data/prepare.sh
./prepare-data/prepare.sh

# 2. Benchmark one version, a few, or all of them.
./run-version.sh 1.1.54378
./run-all.sh 1.1.54378 19.6.3.18 24.8.1.1
./run-all.sh                      # every version from list-versions.sh

# 3. Regenerate the website.
./generate-results.sh
```

Requires Docker and a recent `clickhouse` binary (used only for data prep;
install with `curl https://clickhouse.com/ | sh`).

### Runtime and scale

At the original-blog scale, a single version takes on the order of **hours**
(measured ~4h on `1.1.54019`), dominated by loading the ~1.3B-row taxi table and
the cold first run of each query. The full ~143-version sweep is therefore a
**multi-week** job. To make it tractable, dial down the dominant dataset at prep
time, e.g. a ~100M-row taxi slice:

```bash
TAXI_GLOB='trips_xa[a-n].csv.gz' ./prepare-data/taxi.sh   # ~14 of 175 files
```

Smaller `HITS_PARTS` / `SSB_SCALE` reduce the others similarly. The runner is
unchanged — only the prepared file sizes differ.

## Query set

75 queries in a fixed order: mgbench (15) + Star Schema Benchmark (13) +
ClickBench/hits (43) + taxi (4). See `queries/*.sql`. Results are reported one
row per query, with `null` for queries a given version cannot run.

The previous apt-based scripts are kept under `scripts/` and `unified_scripts/`
for reference.

## Old-version repair

Two fixes let the benchmark reach back to the very first published image
(`1.1.54019`, Sept 2016):

- **IPv4 listen override** (`config/listen.xml`, mounted into every image):
  old images default to `<listen_host>::</listen_host>` (IPv6) and crash on
  boot when the host has IPv6 disabled.
- **Sidecar client**: the oldest server images ship only `clickhouse-server`,
  no client binary. The runner detects this and drives them with the
  matching-version `yandex/clickhouse-client:<v>` image as a sidecar sharing
  the server's network namespace — same native protocol, precise `--time`.

With these, `1.1.54019` runs 62 of the 75 queries; the 13 nulls are genuine
era limitations (e.g. `Nullable`, which mgbench `logs1`/`logs3` need, postdates
that build; likewise a few `toYYYYMM` / `replaceOne` / `COUNT(DISTINCT)` cases).

## Notes and limitations

- The 8 oldest builds (`1.1.54011`, `54165`, `54318`, `54335`, `54336`,
  `54358`, `54362`, `54370`) were never published as an image or package, so
  `list-versions.sh` lists them with the marker `unavailable` and the sweep
  skips them. Everything from `1.1.54019` on is runnable.
- A version that fails to start, create a table, or load data is recorded as a
  failure / `null` rows rather than aborting the sweep.
- Native files are stored zstd-compressed (level 6) and streamed through
  `zstd -dc | clickhouse-client` at load time.
- Validated end-to-end on `1.1.54019` (oldest, via sidecar), `1.1.54378`
  (legacy baseline), `19.8.3.8` (mid), and a modern `24.8` release.
