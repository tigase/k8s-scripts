#!/bin/bash
#
# Script adds a new helm source to the FluxCD repository
#

source ~/envs/cluster.env || exit 1

INTERVAL="${DEF_INTERVAL}"
NAME=""
URL=""
DIR="${BASE_DIR}/sources"

[[ -z "$1" ]] && { echo "Missing name argument"; } || { NAME="$1"; }

[[ -z "$1" || "$1" == "-h" ]] && {
  echo "\$1 - name"
  echo "\$2 - url"
  exit 0
}

[[ -z "$2" ]] && { echo "Missing url argument"; exit 1; } || {
  URL="$2"
}

FILE="${DIR}/"${NAME}".yaml"
flux create source helm ${NAME} \
  --url=${URL} \
  --interval=${INTERVAL} \
  --export > "${FILE}"

cd ${DIR}
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive
cd -

