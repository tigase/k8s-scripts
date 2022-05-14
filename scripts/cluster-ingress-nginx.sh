#!/bin/bash
#
# Script installs nginx as ingress service
#

source `dirname "$0"`/scripts-env-init.sh

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "No cluster repo dir!"; exit 1; }

name="${IN_S_NAME}"
url="${IN_URL}"

echo "      ${BOLD}Adding ${name} source at ${url}${NORMAL}"
${SCRIPTS}/flux-create-source.sh ${name} ${url}
update_repo "${IN_NAME}"
wait_for_ready 5

NAME="${IN_NAME}"
TNS="${IN_TARGET_NAMESPACE}"

CL_DIR=`mkdir_ns ${BASE_DIR} ${TNS} ${FLUX_NS}`

echo "   ${BOLD}Deploying ${NAME}${NORMAL}"
${SCRIPTS}/flux-create-helmrel.sh \
        "${IN_NAME}" \
        "${IN_VER}" \
        "${IN_RNAME}" \
        "${IN_TARGET_NAMESPACE}" \
        "${IN_NAMESPACE}" \
        "${IN_SOURCE}" \
        "${IN_VALUES}" --create-target-namespace || exit 1

update_chart_ns "${CL_DIR}/${NAME}/${NAME}.yaml"
yq e -i '.spec.install.remediation.retries = 3' "${CL_DIR}/${NAME}/${NAME}.yaml"
yq e -i '.spec.upgrade.remediation.retries = 3' "${CL_DIR}/${NAME}/${NAME}.yaml"

update_repo "${NAME}"

wait_for_ready

