#!/bin/bash -x

# Launch a fresh VM that benchmarks ONE ClickHouse version unattended and sends
# the result to the sink (see cloud-init.sh.in), then self-terminates.
#
#   ./run-benchmark.sh <version>
#   machine=c6a.metal datasets="hits ssb mgbench" ./run-benchmark.sh 1.1.54378
#
# version is resolved against list-versions.sh to find its image; for versions
# built from source (clickhouse-built:<v>) the git tag and required GCC are read
# from build-from-source/versions.txt and the VM builds the image itself.

set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${HERE}"

VERSION="${1:?usage: run-benchmark.sh <version>}"
machine="${machine:=c7a.4xlarge}"
repo="${repo:=ClickHouse/ClickBench}"
branch="${branch:=main}"
datasets="${datasets:=hits ssb mgbench}"   # taxi skipped by default (huge); add 'taxi' to include
tries="${tries:=3}"
timeout="${timeout:-18000}"                 # load + (optional source build) + queries
volume="${volume:-500}"                     # GB; raise well past 1000 if including taxi

# Resolve the version against list-versions.sh: accept an exact version
# (26.6.1.1193, 1.1.54378, 53973) or an unambiguous prefix at a dot boundary
# (26.6 -> 26.6.1.1193, since exactly one patch per YY.MM is kept).
LV="$(./list-versions.sh)"
line="$(awk -F'\t' -v v="${VERSION}" '$1==v' <<<"${LV}")"
if [ -z "${line}" ]; then
    line="$(awk -F'\t' -v v="${VERSION}" 'index($1, v".")==1' <<<"${LV}")"
    n="$(grep -c . <<<"${line}"; true)"
    if [ "${n}" -gt 1 ]; then
        echo "ambiguous version '${VERSION}', matches:" >&2; cut -f1 <<<"${line}" >&2; exit 1
    fi
fi
[ -z "${line}" ] && { echo "unknown version: ${VERSION}" >&2; exit 1; }
VERSION="$(cut -f1 <<<"${line}")"   # canonicalise to the full version
image="$(cut -f2 <<<"${line}")"
[ "${image}" = "unavailable" ] && { echo "${VERSION} is unavailable (no image/package/source)" >&2; exit 1; }
echo "resolved to ${VERSION} (${image})"

# For source-built versions, get the tag and required GCC from versions.txt.
tag="-"; gcc="5"
if [[ "${image}" == clickhouse-built:* ]]; then
    read -r tag gcc < <(awk -F'\t' -v v="${VERSION}" '$1==v{print $2, ($4==""?5:$4)}' build-from-source/versions.txt)
    [ -z "${tag}" ] && { echo "no build recipe for ${VERSION} in versions.txt" >&2; exit 1; }
fi

arch=$(aws ec2 describe-instance-types --instance-types "$machine" --query 'InstanceTypes[0].ProcessorInfo.SupportedArchitectures' --output text)
ami=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04*" "Name=architecture,Values=${arch}" "Name=state,Values=available" --query 'sort_by(Images, &CreationDate) | [-1].[ImageId]' --output text)

awk -v repo="$repo" -v branch="$branch" -v version="$VERSION" -v image="$image" \
    -v tag="$tag" -v gcc="$gcc" -v datasets="$datasets" -v tries="$tries" -v t="$timeout" '
{
    gsub(/@repo@/, repo); gsub(/@branch@/, branch); gsub(/@version@/, version)
    gsub(/@image@/, image); gsub(/@tag@/, tag); gsub(/@gcc@/, gcc)
    gsub(/@datasets@/, datasets); gsub(/@tries@/, tries); gsub(/@timeout@/, t)
    print
}' cloud-init.sh.in > "cloud-init.${VERSION}.sh"

# Retry on transient capacity / quota errors (same shape as the main launcher).
RETRY_RE='InsufficientInstanceCapacity|VcpuLimitExceeded|InstanceLimitExceeded|MaxSpotInstanceCountExceeded'
while :; do
    out=$(AWS_PAGER='' aws ec2 run-instances --image-id "$ami" --instance-type "$machine" \
        --block-device-mappings "DeviceName=/dev/sda1,Ebs={DeleteOnTermination=true,VolumeSize=${volume},VolumeType=gp2}" \
        --instance-initiated-shutdown-behavior terminate \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=clickbench-versions-${VERSION}}]" \
        --user-data "file://cloud-init.${VERSION}.sh" 2>&1) && rc=0 || rc=$?

    if [ "$rc" -eq 0 ]; then printf '%s\n' "$out"; break; fi
    reason=$(printf '%s' "$out" | grep -oE "$RETRY_RE" | head -n1)
    if [ -n "$reason" ]; then
        printf 'run-instances: %s for %s, retrying in 60s...\n' "$reason" "$machine" >&2
        sleep 60; continue
    fi
    printf '%s\n' "$out" >&2; exit "$rc"
done
