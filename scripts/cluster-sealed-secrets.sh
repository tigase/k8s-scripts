#!/bin/bash
#
# Script deploys sealed secrets on the k8s cluster and adds public key
# to the git repository so later, secrets can be encrypted.
#

source ~/envs/cluster.env || exit 1
source ~/envs/versions.env || exit 1
source ${SCRIPTS}/cluster-tools.sh || exit 1

cd ${CLUSTER_REPO_DIR}

echo "Deploying sealed secrets"
~/scripts/flux-create-helmrel.sh \
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

update_repo "publiec-key"

