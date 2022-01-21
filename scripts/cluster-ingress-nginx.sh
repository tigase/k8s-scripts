#!/bin/bash
#
# Script installs nginx as ingress service
#

source ~/envs/cluster.env || exit 1
source ~/envs/versions.env || exit 1
source ${SCRIPTS}/cluster-tools.sh || exit 1

NAME="${IN_NAME}"
TNS="${IN_TARGET_NAMESPACE}"

cd ${CLUSTER_REPO_DIR}

CL_DIR=`mkdir_ns ${BASE_DIR} ${TNS} ${FLUX_NS}`

echo "Deploying ${NAME}"
~/scripts/flux-create-helmrel.sh \
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

#wait_for_ready

