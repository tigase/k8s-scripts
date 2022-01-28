#!/bin/bash
#
# Script adds a new helm source to the FluxCD repository
#

source `dirname "$0"`/scripts-env-init.sh

INTERVAL="${DEF_INTERVAL}"
NAME=""
URL=""
DIR="${BASE_DIR}/sources"

[[ -z "$1" ]] && { echo "${ERROR}Missing name argument${NORMAL}"; } || { NAME="$1"; }

[[ -z "$1" || "$1" == "-h" ]] && {
  echo "\$1 - name"
  echo "\$2 - url"
  exit 0
}

[[ -z "$2" ]] && { echo "${ERROR}Missing url argument${NORMAL}"; exit 1; } || {
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

