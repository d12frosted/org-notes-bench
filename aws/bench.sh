#!/usr/bin/env bash
# Run the benchmark on a fresh EC2 instance with a local NVMe disk.
#
#   aws/bench.sh [options]
#
# Needs a valid AWS session (`aws login`) and a default VPC in the
# configured region.  Creates an instance, a key pair and a security
# group that lets in SSH from this machine's IP only, runs the
# benchmark there and copies the results to results/aws/RUN/.  Every
# resource it created is removed on exit, whatever happens, unless
# --keep is given.  As a backstop the instance also terminates itself
# after --max-hours.
#
# Options:
#   --tool NAME        a tool from tools.el (repeatable)
#   --tree NAME=DIR    vulpea sources from a local checkout, benchmarked
#                      as tool NAME (repeatable); the *.el files of DIR
#                      are copied as they are on disk, uncommitted
#                      changes included
#   --sizes N,N        corpus sizes (default 10000)
#   --ops OP,OP        operations, run in this order (default first-run)
#   --repeat N         rounds; each round runs every tool once, so tools
#                      interleave (default 3)
#   --state DIR        where tool state lives: nvme (default, the local
#                      SSD) or tmpfs (in memory, for CPU-only changes)
#   --type TYPE        instance type; needs local instance storage
#                      (default c7gd.2xlarge: 8 Graviton cores, 16GB,
#                      474GB NVMe)
#   --emacs VERSION    Emacs release built from source (default 30.2)
#   --max-hours N      instance self-terminates after N hours (default 3)
#   --keep             leave the instance running and print how to reach it
#
# Example: compare a vulpea branch with master at 10k and 100k notes
#   aws/bench.sh --tree base=../vulpea-master --tree branch=../vulpea \
#     --sizes 10000,100000 --ops first-run --repeat 3

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TYPE=c7gd.2xlarge
EMACS_VERSION=30.2
SIZES=10000
OPS=first-run
REPEAT=3
STATE=nvme
MAX_HOURS=3
KEEP=0
TOOLS=""
TREES=""

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --tool) TOOLS="$TOOLS $2"; shift 2 ;;
    --tree) case "$2" in *=*) ;; *) die "--tree wants NAME=DIR" ;; esac
            dir=$(cd "${2#*=}" && pwd) || die "no such directory: ${2#*=}"
            ls "$dir"/vulpea.el >/dev/null 2>&1 || die "$dir has no vulpea.el"
            TREES="$TREES ${2%%=*}=$dir"; shift 2 ;;
    --sizes) SIZES=$2; shift 2 ;;
    --ops) OPS=$2; shift 2 ;;
    --repeat) REPEAT=$2; shift 2 ;;
    --state) STATE=$2; shift 2 ;;
    --type) TYPE=$2; shift 2 ;;
    --emacs) EMACS_VERSION=$2; shift 2 ;;
    --max-hours) MAX_HOURS=$2; shift 2 ;;
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
done

[ -n "$TOOLS$TREES" ] || die "nothing to benchmark: pass --tool or --tree"
case "$STATE" in nvme|tmpfs) ;; *) die "--state is nvme or tmpfs" ;; esac
for spec in $TREES; do
  case "${spec%%=*}" in *[!a-z0-9-]*|"") die "tree name must be [a-z0-9-]: ${spec%%=*}" ;; esac
done

aws sts get-caller-identity >/dev/null 2>&1 \
  || die "no valid AWS session; run 'aws login' first"
REGION=$(aws configure get region || true)
[ -n "$REGION" ] || die "no region configured (aws configure set region ...)"

RUN=onb-$(date +%Y%m%d-%H%M%S)
OUT=$ROOT/results/aws/$RUN
mkdir -p "$OUT"
KEY=$OUT/key.pem
log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$OUT/driver.log"; }

ARCH=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].ProcessorInfo.SupportedArchitectures[0]' --output text)
DISK=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].InstanceStorageInfo.TotalSizeInGB' --output text)
[ "$DISK" != "None" ] || die "$TYPE has no local instance storage; pick a 'd' type (c7gd, m7gd, c6id, ...)"
case "$ARCH" in arm64) UBUNTU_ARCH=arm64 ;; x86_64) UBUNTU_ARCH=amd64 ;; *) die "unsupported architecture $ARCH" ;; esac
AMI=$(aws ssm get-parameter \
  --name "/aws/service/canonical/ubuntu/server/24.04/stable/current/$UBUNTU_ARCH/hvm/ebs-gp3/ami-id" \
  --query Parameter.Value --output text)
VPC=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
[ "$VPC" != "None" ] || die "no default VPC in $REGION"
MYIP=$(curl -fsS https://checkip.amazonaws.com)

IID=""
SG=""
cleanup() {
  status=$?
  if [ "$KEEP" = 1 ] && [ -n "$IID" ]; then
    log "kept $IID; reach it with: ssh -i $KEY ubuntu@${IP:-?}"
    log "remove it with: aws ec2 terminate-instances --instance-ids $IID, then delete security group $SG and key pair $RUN"
    exit $status
  fi
  log "cleaning up"
  if [ -n "$IID" ]; then
    aws ec2 terminate-instances --instance-ids "$IID" >/dev/null || true
    aws ec2 wait instance-terminated --instance-ids "$IID" || true
  fi
  if [ -n "$SG" ]; then
    # The instance's network interface can outlive it by a few seconds
    for _ in 1 2 3 4 5 6; do
      aws ec2 delete-security-group --group-id "$SG" >/dev/null 2>&1 && SG="" && break
      sleep 10
    done
    [ -z "$SG" ] || log "could not delete security group $SG, remove it by hand"
  fi
  aws ec2 delete-key-pair --key-name "$RUN" >/dev/null 2>&1 || true
  rm -f "$KEY"
  log "removed everything this run created"
  exit $status
}
trap cleanup EXIT
trap 'exit 130' INT TERM

log "run $RUN: $TYPE ($ARCH, ${DISK}GB local NVMe) in $REGION, Emacs $EMACS_VERSION, state on $STATE"
aws ec2 create-key-pair --key-name "$RUN" --key-type ed25519 \
  --tag-specifications "ResourceType=key-pair,Tags=[{Key=Project,Value=org-notes-bench}]" \
  --query KeyMaterial --output text > "$KEY"
chmod 600 "$KEY"
SG=$(aws ec2 create-security-group --group-name "$RUN" --vpc-id "$VPC" \
  --description "org-notes-bench $RUN, ssh from one address" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Project,Value=org-notes-bench}]" \
  --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG" \
  --protocol tcp --port 22 --cidr "$MYIP/32" >/dev/null

USERDATA=$(printf '#!/bin/sh\nshutdown -h +%d\n' $((MAX_HOURS * 60)))
IID=$(aws ec2 run-instances --image-id "$AMI" --instance-type "$TYPE" \
  --key-name "$RUN" --security-group-ids "$SG" \
  --instance-initiated-shutdown-behavior terminate \
  --user-data "$USERDATA" \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":30,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$RUN},{Key=Project,Value=org-notes-bench}]" \
  --query 'Instances[0].InstanceId' --output text)
log "instance $IID launched, waiting for it"
aws ec2 wait instance-running --instance-ids "$IID"
IP=$(aws ec2 describe-instances --instance-ids "$IID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

SSH_OPTS="-i $KEY -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$OUT/known_hosts -o ConnectTimeout=10 -o ServerAliveInterval=30 -o LogLevel=ERROR"
rsh() { ssh $SSH_OPTS "ubuntu@$IP" "$@"; }
rcp() { scp -q $SSH_OPTS "$@"; }
for _ in $(seq 1 60); do rsh true 2>/dev/null && break; sleep 5; done
rsh true || die "instance never accepted SSH"

# The harness without its generated data, and each tree's sources
STAGE=$(mktemp -d)
tar -C "$ROOT" -czf "$STAGE/onb.tgz" --exclude=./.deps --exclude=./data/corpus-* \
  --exclude=./data/state --exclude=./data/prof-state --exclude=./results \
  --exclude=./.git --exclude='*.log' --exclude='*.elc' .
mkdir -p "$STAGE/trees"
: > "$OUT/env.txt"
for spec in $TREES; do
  name=${spec%%=*}; dir=${spec#*=}
  mkdir -p "$STAGE/trees/$name"
  cp "$dir"/*.el "$STAGE/trees/$name/"
  rev=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo "?")
  dirty=$(git -C "$dir" status --porcelain -- '*.el' 2>/dev/null | head -1)
  echo "tree $name: $dir at $rev${dirty:+ (with uncommitted changes)}" >> "$OUT/env.txt"
done
tar -C "$STAGE" -czf "$STAGE/trees.tgz" trees
rcp "$STAGE/onb.tgz" "$STAGE/trees.tgz" "$ROOT/aws/remote-setup.sh" "$ROOT/aws/remote-run.sh" "ubuntu@$IP:"
rm -rf "$STAGE"

TREE_NAMES=$(for spec in $TREES; do printf '%s ' "${spec%%=*}"; done)
ALL_TOOLS="$TREE_NAMES$TOOLS"
{
  echo "instance: $TYPE ($ARCH) in $REGION, AMI $AMI"
  echo "emacs: $EMACS_VERSION built from source; state on $STATE"
  echo "tools: $ALL_TOOLS"
  echo "sizes: $SIZES; ops: $OPS; rounds: $REPEAT"
} >> "$OUT/env.txt"

# Run detached on the instance, so a dropped connection cannot stop it
log "setting up (building Emacs takes about 10 minutes), then benchmarking"
rsh "nohup bash -c 'bash remote-setup.sh $EMACS_VERSION $STATE > setup.log 2>&1 && bash remote-run.sh \"$TREE_NAMES\" \"$ALL_TOOLS\" $SIZES $OPS $REPEAT > run.log 2>&1; echo \$? > finished' > /dev/null 2>&1 < /dev/null &"

seen=0
deadline=$(( $(date +%s) + MAX_HOURS * 3600 ))
while ! rsh test -f finished 2>/dev/null; do
  [ "$(date +%s)" -lt "$deadline" ] || die "no result after $MAX_HOURS hours"
  sleep 30
  # Show benchmark lines as they land
  lines=$(rsh "cat run.log 2>/dev/null | wc -l" 2>/dev/null || echo "$seen")
  if [ "$lines" -gt "$seen" ]; then
    rsh "sed -n '$((seen + 1)),${lines}p' run.log" 2>/dev/null | cut -c1-220 | tee -a "$OUT/driver.log"
    seen=$lines
  fi
done
code=$(rsh cat finished)
rcp "ubuntu@$IP:setup.log" "ubuntu@$IP:run.log" "$OUT/" || true
rcp "ubuntu@$IP:/mnt/bench/onb/results/raw.jsonl" "$OUT/raw.jsonl" 2>/dev/null || true
rsh "emacs --version | head -1" >> "$OUT/env.txt" 2>/dev/null || true

if [ "$code" != 0 ]; then
  log "the run failed (exit $code); see $OUT/setup.log and $OUT/run.log"
  exit 1
fi
log "results in $OUT"
[ -f "$OUT/raw.jsonl" ] && emacs -Q --batch -l "$ROOT/aws/compare.el" "$OUT/raw.jsonl" | tee "$OUT/summary.md"
