#!/bin/bash
# 
# Script deploys loki for collecting logs from k8s services
# 

source ~/envs/cluster.env || exit 1
source ~/envs/versions.env || exit 1
source ${SCRIPTS}/cluster-tools.sh || exit 1

NAME="${LO_NAME}"
TNS="${LO_TARGET_NAMESPACE}"

cd ${CLUSTER_REPO_DIR}

CL_DIR=`mkdir_ns ${BASE_DIR} ${TNS} ${FLUX_NS}`

echo "Deploying ${NAME}"
~/scripts/flux-create-helmrel.sh \
        "${LO_NAME}" \
        "${LO_VER}" \
        "${LO_RNAME}" \
        "${LO_TARGET_NAMESPACE}" \
        "${LO_NAMESPACE}" \
        "${LO_SOURCE}" \
        "${LO_VALUES}" --create-target-namespace || exit 1

update_chart_ns "${CL_DIR}/${NAME}/${NAME}.yaml"

update_repo "${NAME}"

