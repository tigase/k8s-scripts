#!/bin/bash
#
# Script deploys Weblate on the k8s cluster.
#

source `dirname "$0"`/scripts-env-init.sh

INTERVAL="${DEF_INTERVAL}"
SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-${CLUSTER_NAME}.pem"

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "${ERROR}No cluster repo dir!${NORMAL}"; exit 1; }

TNS=${WEBLATE_TARGET_NAMESPACE}

echo "      ${BOLD}Adding Weblate helm chart${NORMAL}"

${SCRIPTS}/flux-create-source.sh ${WEBLATE_S_NAME} ${WEBLATE_URL}

update_kustomization ${BASE_DIR}/sources

echo "      ${BOLD}Preparing Weblate deployment${NORMAL}"

NAME="${WEBLATE_NAME}"

${SCRIPTS}/flux-create-helmrel.sh app \
        "${WEBLATE_NAME}" \
        "${WEBLATE_VER}" \
        "${WEBLATE_RNAME}" \
        "${WEBLATE_TARGET_NAMESPACE}" \
        "${WEBLATE_NAMESPACE}" \
        "${WEBLATE_SOURCE}" \
        "${WEBLATE_VALUES}" --create-target-namespace || exit 1

echo "      ${BOLD}Deploying changes${NORMAL}"

update_repo ${NAME}

wait_for_ready
