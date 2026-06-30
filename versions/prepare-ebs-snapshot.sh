#!/usr/bin/env bash
# Build an EBS snapshot that holds the prepared Native data files, so benchmark
# VMs attach it as a small read-only data volume instead of re-downloading the
# datasets every time. Run on an EC2 instance whose role/creds can manage EBS
# (this prep box works once `aws` is configured — it already has the files).
#
#   ./prepare-ebs-snapshot.sh
#   DATASETS="hits ssb mgbench" ./prepare-ebs-snapshot.sh   # leave out taxi
#   SRC=s3 ./prepare-ebs-snapshot.sh                        # download from the bucket instead of local files
#
# The volume is filesystem-labelled "versions-data"; the snapshot is tagged
# Name=clickbench-versions-data. The working volume is deleted afterwards — only
# the snapshot is kept.
#
# NOTE: a volume restored from a snapshot is lazy-loaded from S3 (blocks fetched
# on first read), so for one-shot VMs that read the data once it is NOT faster
# than downloading from S3 — and gp3's 125 MB/s baseline can be slower than a
# parallel in-region S3 download. It only pays off with Fast Snapshot Restore
# (paid, per AZ) or when the volume is reused across many runs. This script is
# kept as a standalone option; cloud-init.sh.in downloads from S3 by default.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAP_NAME="${SNAP_NAME:-clickbench-versions-data}"
LABEL="${LABEL:-versions-data}"
DATASETS="${DATASETS:-hits ssb mgbench taxi}"
SRC="${SRC:-${HERE}/prepare-data/data}"      # local dir, or "s3" to download
BUCKET='https://clickhouse-public-datasets.s3.amazonaws.com/versions-benchmark'

files_for() { case "$1" in
    hits) echo hits.native.zst;; ssb) echo ssb.native.zst;; taxi) echo taxi.native.zst;;
    mgbench) echo mgbench1.native.zst mgbench2.native.zst mgbench3.native.zst;; esac; }
FILES=(); for ds in ${DATASETS}; do FILES+=($(files_for "${ds}")); done

# --- size the volume to just fit the files (+headroom for the filesystem) -----
bytes=0
for f in "${FILES[@]}"; do
    if [ "${SRC}" = "s3" ]; then
        s=$(curl -fsSI "${BUCKET}/${f}" | awk 'tolower($1)=="content-length:"{print $2}' | tr -d '\r')
    else
        s=$(stat -c%s "${SRC}/${f}" 2>/dev/null || echo 0)
    fi
    bytes=$(( bytes + ${s:-0} ))
done
[ "${bytes}" -gt 0 ] || { echo "no source files found for: ${DATASETS}" >&2; exit 1; }
SIZE_GB=$(( bytes / 1000000000 + 3 ))      # ~headroom + ext4 overhead
[ "${SIZE_GB}" -lt 8 ] && SIZE_GB=8
echo "including: ${FILES[*]}"
echo "volume size: ${SIZE_GB} GB"

# --- this instance / AZ -------------------------------------------------------
TOKEN=$(curl -sS -X PUT 'http://169.254.169.254/latest/api/token' -H 'X-aws-ec2-metadata-token-ttl-seconds: 600')
md() { curl -sS -H "X-aws-ec2-metadata-token: ${TOKEN}" "http://169.254.169.254/latest/meta-data/$1"; }
IID=$(md instance-id); AZ=$(md placement/availability-zone)

# --- create + attach a blank volume -------------------------------------------
VOL=$(AWS_PAGER='' aws ec2 create-volume --availability-zone "${AZ}" --size "${SIZE_GB}" \
    --volume-type gp3 --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=${SNAP_NAME}-build}]" \
    --query VolumeId --output text)
echo "created volume ${VOL}; attaching to ${IID} ..."
cleanup() { AWS_PAGER='' aws ec2 detach-volume --volume-id "${VOL}" >/dev/null 2>&1 || true
            aws ec2 wait volume-available --volume-ids "${VOL}" 2>/dev/null || true
            AWS_PAGER='' aws ec2 delete-volume --volume-id "${VOL}" >/dev/null 2>&1 || true; }
trap cleanup EXIT
aws ec2 wait volume-available --volume-ids "${VOL}"
AWS_PAGER='' aws ec2 attach-volume --volume-id "${VOL}" --instance-id "${IID}" --device /dev/sdf >/dev/null
aws ec2 wait volume-in-use --volume-ids "${VOL}"

# Find the device (Nitro exposes EBS as NVMe with serial = volume id sans dash).
DEV=""
for _ in $(seq 1 30); do
    DEV=$(lsblk -dpno NAME,SERIAL | awk -v s="${VOL//-/}" 'index($2,s){print $1; exit}')
    [ -n "${DEV}" ] && break; sleep 2
done
[ -n "${DEV}" ] || { echo "could not find attached device for ${VOL}" >&2; exit 1; }
echo "device: ${DEV}"

# --- format, populate, unmount ------------------------------------------------
sudo mkfs.ext4 -q -L "${LABEL}" "${DEV}"
MNT=$(mktemp -d); sudo mount "${DEV}" "${MNT}"; sudo chown "$(id -u)" "${MNT}"
for f in "${FILES[@]}"; do
    if [ "${SRC}" = "s3" ]; then
        echo "downloading ${f} ..."; wget --continue --progress=dot:giga -P "${MNT}" "${BUCKET}/${f}"
    else
        echo "copying ${f} ..."; cp "${SRC}/${f}" "${MNT}/${f}"
    fi
done
sync; ls -lh "${MNT}"; sudo umount "${MNT}"; rmdir "${MNT}"

# --- snapshot, then drop the working volume (trap) ----------------------------
AWS_PAGER='' aws ec2 detach-volume --volume-id "${VOL}" >/dev/null
aws ec2 wait volume-available --volume-ids "${VOL}"
SNAP=$(AWS_PAGER='' aws ec2 create-snapshot --volume-id "${VOL}" \
    --description "versions-benchmark datasets: ${FILES[*]}" \
    --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=${SNAP_NAME}},{Key=datasets,Value=${DATASETS// /,}}]" \
    --query SnapshotId --output text)
echo "snapshot ${SNAP} creating; waiting for completion ..."
aws ec2 wait snapshot-completed --snapshot-ids "${SNAP}"
echo "DONE: ${SNAP} (label ${LABEL}, ${SIZE_GB} GB, tag Name=${SNAP_NAME})"
