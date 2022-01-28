#!/bin/bash
# 
# Script deploys loki for collecting logs from k8s services
# 

source `dirname "$0"`/scripts-env-init.sh

NAME="${LO_NAME}"
TNS="${LO_TARGET_NAMESPACE}"

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "${ERROR}No cluster repo dir!${NORMAL}"; exit 1; }

CL_DIR=`mkdir_ns ${BASE_DIR} ${TNS} ${FLUX_NS}`

echo "   ${BOLD}Deploying ${NAME}${NORMAL}"
${SCRIPTS}/flux-create-helmrel.sh \
        "${LO_NAME}" \
        "${LO_VER}" \
        "${LO_RNAME}" \
        "${LO_TARGET_NAMESPACE}" \
        "${LO_NAMESPACE}" \
        "${LO_SOURCE}" \
        "${LO_VALUES}" --create-target-namespace || exit 1

update_chart_ns "${CL_DIR}/${NAME}/${NAME}.yaml"

update_repo "${NAME}"

