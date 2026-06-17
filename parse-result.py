#!/usr/bin/env python3
"""
Parse a benchmark.sh log into the standard ClickBench result JSON.

Reads the log path from argv[1] (default /tmp/umbra-bench.log) and emits the
result JSON on stdout. Metadata (system/proprietary/hardware/tuned/tags) comes
from template.json in the system directory; date/machine/cluster_size and the
"system" title bits are supplied via the BENCH_DATE / BENCH_MACHINE /
BENCH_CLUSTER_SIZE environment variables (run-benchmark sets these). The title
is "Umbra", with an optional TAG in parentheses.

The log shape is what lib/benchmark-common.sh prints:
  [t1,t2,t3],            one line per query, in order (cold, warm, warm)
  Load time: <secs>
  Data size: <bytes>
  Concurrent QPS: <n|null>
  Concurrent error ratio: <n|null>
"""
import json
import os
import re
import sys
from pathlib import Path

log_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/tmp/umbra-bench.log")
lines = log_path.read_text().splitlines()

# 1. Pull [t1,t2,t3] lines in order.
triples_re = re.compile(r"^\[([^\]]+)\],\s*$")
triples = []
for ln in lines:
    m = triples_re.match(ln)
    if not m:
        continue
    parts = m.group(1).split(",")
    row = [None if p.strip() == "null" else round(float(p), 3) for p in parts]
    triples.append(row)

if len(triples) != 43:
    print(f"warn: expected 43 query triples, got {len(triples)}", file=sys.stderr)
if not triples:
    sys.exit("error: no query timings found in log; benchmark.sh may have failed")

# 2. Pull the scalar measurements.
def grab(prefix):
    for ln in lines:
        if ln.startswith(prefix):
            return ln[len(prefix):].strip()
    return None

def num(value, cast):
    if value is None or value == "null":
        return None
    return cast(value)

load_time = num(grab("Load time: "), float)
data_size = num(grab("Data size: "), int)
qps = num(grab("Concurrent QPS: "), float)
err_ratio = num(grab("Concurrent error ratio: "), float)

if load_time is None:
    sys.exit("error: no 'Load time:' line found in log")
if data_size is None:
    sys.exit("error: no 'Data size:' line found in log")

template = json.loads(Path("template.json").read_text())

# Title: "Umbra", with an optional TAG in parentheses
# (e.g. "Umbra (prefetch)") to match the existing result files.
tag = os.environ.get("BENCH_TAG", "")
system = template["system"]
if tag:
    system += f" ({tag})"

out = {
    "system": system,
    "date": os.environ["BENCH_DATE"],
    "machine": os.environ["BENCH_MACHINE"],
    "cluster_size": int(os.environ.get("BENCH_CLUSTER_SIZE", "1")),
    "proprietary": template["proprietary"],
    "hardware": template["hardware"],
    "tuned": template["tuned"],
    "tags": template["tags"],
    "load_time": round(load_time, 3),
    "data_size": data_size,
}
# Only emit the concurrency fields when the run actually produced them, so a
# sweep that skipped the QPS phase doesn't write nulls into the result.
if qps is not None:
    out["concurrent_qps"] = qps
if err_ratio is not None:
    out["concurrent_error_ratio"] = err_ratio
out["result"] = triples

print(json.dumps(out, indent=4))
