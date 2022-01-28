#!/bin/bash
#
# Script adds a new helm release to the FluxCD repository and
# kustomization metadata
#

source `dirname "$0"`/scripts-env-init.sh

INTERVAL="${DEF_INTERVAL}"
NAME=""
VERSION=""
NAMESPACE="flux-system"
TARGET_NAMESPACE="${NAMESPACE}"
#URL=""

#### $1

## Check if this is app setup
[[ "$1" == "app" ]] && { BASE_DIR="${APPS_DIR}"; shift; }
[[ -z "$1" ]] && { echo "${ERROR}Missing name argument${NORMAL}"; } || { NAME="$1"; }

[[ -z "$1" || "$1" == "-h" ]] && {
  echo "CLUSTER_NAME environment variable must be set"
  echo "\$1 - name - package name"
  echo "\$2 - chart version"
#  echo "\$3 - url - HelmRepository source URL"
  echo "\$3 - release name [name]"
  echo "\$4 - target namespace"
  echo "\$5 - namespace"
  echo "\$6 - source [HelmRepository/name]"
  echo "Any flux compatible parameter will be appended to thend of the command"
  exit 0
}

[[ -z "${CLUSTER_NAME}" ]] && { echo "{ERROR}CLUSTER_NAME env not set!${NORMAL}"; exit 1; }

REL_NAME="${NAME}"
SOURCE="HelmRepository/${NAME}"
CHART="${NAME}"

shift

#### $2
[[ -z "$1" ]] && { echo "${ERROR}Missing version argument${NORMAL}"; exit 1; } || { VERSION="$1"; shift; }
#### $3
#[[ -z "$1" ]] || { URL="$1"; shift; }
#### $3
[[ -z "$1" ]] || { REL_NAME="$1"; shift; }
#### $4
[[ -z "$1" ]] || { TARGET_NAMESPACE="$1"; shift; }
#### $5
[[ -z "$1" ]] || { NAMESPACE="$1"; shift; }
#### $6
[[ -z "$1" ]] || { SOURCE="$1"; shift; }

CL_DIR="${BASE_DIR}"

# Services for the same namespace are stored in the same folder
[[ "${TARGET_NAMESPACE}" == "${FLUX_NS}" ]] || {
  echo "Creating folder for ${TARGET_NAMESPACE} namespace..."
  CL_DIR="${CL_DIR}/${TARGET_NAMESPACE}" 
  mkdir -p ${CL_DIR}
  [[ -f "${CL_DIR}/namespace.yaml" ]] || {
cat > "${CL_DIR}/namespace.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${TARGET_NAMESPACE}
EOF
  }
}

DIR="${CL_DIR}/${NAME}"
FILE="${DIR}/${NAME}.yaml"

### check if the target file already exists

[[ -f "${FILE}" ]] && {
  echo "${ERROR}Files are alredy generated, please either edit to update or remove to regenrate:${NORMAL}"
  echo "  - ${FILE}"
  echo "  - ${DIR}/kustomization.yaml"
  exit 2
}

### Safe to proceed with files generation

mkdir -p "${DIR}"

CMD="flux create helmrelease ${NAME} \
	--interval=${INTERVAL} \
	--release-name=${REL_NAME} \
	--source=${SOURCE} \
	--chart-version=${VERSION} \
	--chart=${CHART} \
	--namespace=${NAMESPACE}
	--target-namespace=${TARGET_NAMESPACE} $*"
echo -e "${CMD}\n" >> $TMP_DIR/flux-cmds.txt
set -x
${CMD} --export > ${FILE}
set +x

echo "Update service kustomization"
cd ${DIR}
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd -

[[ "${TARGET_NAMESPACE}" == "${FLUX_NS}" ]] || {
  echo "Update namespace kustomization"
  cd ${CL_DIR}
  rm -f kustomization.yaml
  kustomize create --autodetect --recursive --namespace="${TARGET_NAMESPACE}"
  cd -
}

echo "Update common kustomization"
cd ${BASE_DIR}
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd -

