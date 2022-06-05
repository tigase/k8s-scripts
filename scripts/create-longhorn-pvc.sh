#!/bin/bash

example() {
  echo "Example:"
  echo "$0 name namespace 5Gi /path/to/folder"
  echo "$0 name --remove /path/to/folder"
  exit 1
}


[ -z "$1" ] && {
  echo "Missing volume name"
  example
}

[ -z "$2" ] && {
  echo "Missing volume namespace"
  example
}

source `dirname "$0"`/scripts-env-init.sh
cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "No cluster repo dir!"; exit 1; }

if [ "$2" == "--remove" ] ;  then
  [ -z "$3" ] && {
    echo "Missing volume path"
    example
  }

  CL_DIR=${3}
  PVC_FILE=${CL_DIR}/${1}.yaml

  echo "    Removing ${PVC_FILE}"
  rm -f ${PVC_FILE}
  update_kustomization ${CL_DIR}
  update_repo ${1}
  exit 0
fi

[ -z "$3" ] && {
  echo "Missing volume size"
  example
}

[ -z "$4" ] && {
  echo "Missing volume path"
  example
}

CL_DIR=${4}
PVC_FILE=${CL_DIR}/${1}.yaml

[ -f "${PVC_FILE}" ] && {
  echo "    Volume already created: ${PVC_FILE}"
  exit 1
}

cat <<EOF > ${PVC_FILE}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $1-pv
spec:
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: $3
  persistentVolumeReclaimPolicy: Delete
  volumeMode: Filesystem
  storageClassName: longhorn
  csi:
    driver: driver.longhorn.io
    fsType: ext4
    volumeAttributes:
      numberOfReplicas: '3'
      staleReplicaTimeout: '2880'
    volumeHandle: $1-pv
EOF

cat <<EOF >> ${PVC_FILE}

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $1
  namespace: $2
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: $3
  volumeName: $1-pv
  storageClassName: longhorn

EOF

