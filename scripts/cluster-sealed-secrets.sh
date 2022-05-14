#!/bin/bash
#
# Script deploys sealed secrets on the k8s cluster and adds public key
# to the git repository so later, secrets can be encrypted.
#

source `dirname "$0"`/scripts-env-init.sh

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "No cluster repo dir!"; exit 1; }

name="${SS_S_NAME}"
url="${SS_URL}"

echo "      ${BOLD}Adding ${name} source at ${url}${NORMAL}"
${SCRIPTS}/flux-create-source.sh ${name} ${url}
update_repo "${SS_NAME}"
wait_for_ready 5

echo "   ${BOLD}Deploying sealed secrets${NORMAL}"
${SCRIPTS}/flux-create-helmrel.sh \
        "${SS_NAME}" \
        "${SS_VER}" \
        "${SS_RNAME}" \
        "${SS_TARGET_NAMESPACE}" \
        "${SS_NAMESPACE}" \
        "${SS_SOURCE}" \
        "${SS_VALUES}" --crds=CreateReplace || exit 1

update_repo "${SS_NAME}"

wait_for_ready

kubectl port-forward service/sealed-secrets-controller 8080:8080 -n flux-system &
sleep 10
curl --retry 5 --retry-connrefused localhost:8080/v1/cert.pem > pub-sealed-secrets-${CLUSTER_NAME}.pem
killall kubectl

update_repo "public-key"

