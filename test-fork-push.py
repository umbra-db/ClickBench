#!/usr/bin/env python3
"""One-off driver to test the fork-push path end to end: read a
collect-results comment, download the paste contents, and commit them to
the PR's fork through the same functions collect-new-results.py uses.
Temporary — to be removed once the test passes."""

import importlib.util
import json
import re
import sys

spec = importlib.util.spec_from_file_location("collect", "collect-new-results.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

pr_number, comment_id = sys.argv[1], sys.argv[2]
assert pr_number.isdigit() and comment_id.isdigit()

body = m.gh("api", f"repos/{m.REPO}/issues/comments/{comment_id}", "--jq", ".body")
pairs = re.findall(r"save \[this result\]\(https://pastila\.nl/"
                   r"\?([0-9a-f]+)/([0-9a-f]+)\) as `([^`]+)`", body)
assert pairs, "no 'save this result' links found in the comment"

rows = []
for fingerprint, content_hash, path in pairs:
    path_match = re.match(r"([A-Za-z0-9_-]+)/results/(\d{8})/([a-z0-9._-]+)\.json$",
                          path)
    assert path_match, f"unexpected result path: {path}"
    system, date, machine = path_match.groups()
    response = m.http_post(
        m.PASTILA_DB_URL,
        f"SELECT content FROM data_view(fingerprint = '{fingerprint}', "
        f"hash = '{content_hash}') FORMAT JSON")
    content = json.loads(response)["data"][0]["content"]
    json.loads(content)  # the result file must be valid JSON
    rows.append({"system": system, "date": date, "machine": machine,
                 "output": content})
    print(f"fetched {path}: {len(content)} bytes")

meta = m.pr_meta(pr_number)
head_repo = meta["head"]["repo"]["full_name"]
assert head_repo != m.REPO, "this test is for fork PRs"
assert meta["maintainer_can_modify"], "the PR does not allow maintainer edits"

head_ref = meta["head"]["ref"]
remote = f"https://github.com/{head_repo}.git"
base_sha = m.fetch_branch(head_ref, remote=remote)
print(f"fork head: {base_sha}")

systems = sorted({r["system"] for r in rows})
machines = ", ".join(sorted({r["machine"] for r in rows}))
commit = m.commit_results(
    base_sha, rows, [],
    f"Add benchmark results for {', '.join(systems)} ({machines})",
    head_ref, remote=remote)
print(f"pushed commit: {commit}")
