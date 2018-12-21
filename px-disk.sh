#!/bin/sh

if test -z $1 || test -z $2 ; then
    /bin/echo "usage: $0 <partner name> <environment name>"
    /bin/echo
    /bin/echo "This script is inteneded to run as a kubernetes DaemonSet on alibaba worker nodes"
    /bin/echo "It will look for and attach alicloud cloud disks to workers for use by Portworx (px)"
    /bin/echo "based on appropriately tagged disks, typically created by the terraform templates in"
    /bin/echo "the tf-k8s-alibaba repostiory"
    /bin/echo
    exit 1
fi

log() {
  date=$(date)
  echo "$date [$0] $@"
}

errorExit() {
  log "$@"
  exit 1
}


INSTANCE_ID=$(curl -s -m 2 http://100.100.100.200/latest/meta-data/instance-id) || errorExit "Couldn't get INSTANCE_ID from metadata endpoint"
REGION_ID=$(curl -s -m 2 http://100.100.100.200/latest/meta-data/region-id) || errorExit "Couldn't get REGION_ID from metadata endpoint"
ZONE_ID=$(curl -s -m 2 http://100.100.100.200/latest/meta-data/zone-id) || errorExit "Couldn't get ZONE_ID from metadat endpoint"

CLUSTER_ID="${1}-${2}"
PX_DISK_PREFIX="${CLUSTER_ID}-px-disk"

aliyun configure --mode EcsRamRole set --region ${REGION_ID} || errorExit "Couldn't configure aliyun CLI"

instanceHasPxDisk() {
  INSTANCE_PX_DISK_COUNT=$(aliyun ecs DescribeDisks --InstanceId ${INSTANCE_ID} | jq "[.Disks.Disk[] | select(.Description | contains(\"${PX_DISK_PREFIX}\"))] | length") || errorExit "Couldn't get disk px disk count"
  case "${INSTANCE_PX_DISK_COUNT}" in
    "0")
      return 1
      ;;
    "1")
      return 0
      ;;
    *)
      log "unexpected px disk count for instance: ${INSTANCE_PX_DISK_COUNT}"
      return 1;
  esac
}

pxAvailableDiskCount() {
    PX_AVAILABLE_DISK_COUNT=$(aliyun ecs DescribeDisks | jq "[.Disks.Disk[] | select(.Description | contains(\"${PX_DISK_PREFIX}\")) | select(.Status == \"Available\")] | length") || errorExit "Couldn't get disk px disk count"
    echo ${PX_AVAILABLE_DISK_COUNT}
}

shouldAttachPXDisk() {
    if instanceHasPxDisk; then
      return 1
    fi

    if [ "$(pxAvailableDiskCount)" != "0" ]; then
        return 0
    else
        return 1
    fi
}

getCandidatePxDiskId() {
  DISK_INDEX=$(( $RANDOM % $(pxAvailableDiskCount) ))
  PX_CANDIDATE_DISK=$(aliyun ecs DescribeDisks | jq -r ".Disks.Disk[${DISK_INDEX}] | select(.Description | contains(\"${PX_DISK_PREFIX}\")) | select(.Status == \"Available\") | .DiskId")
  echo ${PX_CANDIDATE_DISK}
}

log "Starting watcher for Alicloud PX disks for cluster ${CLUSTER_ID}, instance: ${INSTANCE_ID}"
log "running in region ${REGION_ID}, zone: ${ZONE_ID}"
log "watching for disks with Description tag: ${PX_DISK_PREFIX}"

while true
do
  if shouldAttachPXDisk; then
    CANDIDATE_DISK_ID=$(getCandidatePxDiskId)
    log "Attempting to attach disk id: ${CANDIDATE_DISK_ID}"
    CMD_OUT=$(aliyun ecs AttachDisk --InstanceId ${INSTANCE_ID} --DiskId ${CANDIDATE_DISK_ID})
    log "Disk attach request: ${CMD_OUT}"
  fi
  sleep 30
done

