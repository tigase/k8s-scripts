#!/bin/bash
#
# Script deploys Mailu on the k8s cluster.
#

source `dirname "$0"`/scripts-env-init.sh

INTERVAL="${DEF_INTERVAL}"
SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-${CLUSTER_NAME}.pem"

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "${ERROR}No cluster repo dir!${NORMAL}"; exit 1; }

TNS=${MAILU_TARGET_NAMESPACE}

if [ -z "${MAILU_HOSTNAME}" ]; then
  echo -n "Provide hostname: "; read h_key;
  [[ -z ${h_key} ]] || MAILU_HOSTNAME=${h_key}
fi

if [ -z "${MAILU_DOMAINS}" ]; then
  MAILU_DOMAINS=()
  while : ; do 
    echo -n "Provide domain to host emails for, or empty to continue: "; read d_key;
    if [[ -z ${d_key} ]]; then
      break;
    else
      idx=$(( ${#MAILU_DOMAINS[@]} + 1 ));
      MAILU_DOMAINS[${idx}]="${d_key}";
        echo "Domains: $idx"
    fi
  done
fi

if [ -z "${MAILU_ADMIN_USERNAME}" ]; then
  echo -n "Provide admin username: "; read u_key;
  echo -n "Provide admin domain: "; read d_key;
  echo -n "Provide admin password: "; read p_key;
  [[ -z ${u_key} ]] || MAILU_ADMIN_USERNAME=${u_key}
  [[ -z ${d_key} ]] || MAILU_ADMIN_DOMAIN=${d_key}
  [[ -z ${p_key} ]] || MAILU_ADMIN_PASSWORD=${p_key}
fi

DOMAINS_COUNT=${#MAILU_DOMAINS[@]}
if [ $DOMAINS_COUNT == 0 ]; then
	echo "No domains!"
	exit 1
fi

VALUES=$"    secretKey: \"${MAILU_ADMIN_PASSWORD}\"\n    domain: \"$MAILU_HOSTNAME\"\n    hostnames:"
for domain in "${MAILU_DOMAINS[@]}"
do
  echo "$i"
  VALUES=$"$VALUES\n      - \"$domain\""
done 

VALUES="$VALUES\n    initialAccount:"
VALUES="$VALUES\n      username: \"${MAILU_ADMIN_USERNAME}\""
VALUES="$VALUES\n      domain: \"${MAILU_ADMIN_DOMAIN}\""
VALUES="$VALUES\n      password: \"${MAILU_ADMIN_PASSWORD}\""

echo "      ${BOLD}Adding Mailu helm chart${NORMAL}"

${SCRIPTS}/flux-create-source.sh ${MAILU_S_NAME} ${MAILU_URL}

update_kustomization ${BASE_DIR}/sources

echo "      ${BOLD}Preparing Mailu deployment${NORMAL}"

NAME="${MAILU_NAME}"

${SCRIPTS}/flux-create-helmrel.sh app \
        "${MAILU_NAME}" \
        "${MAILU_VER}" \
        "${MAILU_RNAME}" \
        "${MAILU_TARGET_NAMESPACE}" \
        "${MAILU_NAMESPACE}" \
        "${MAILU_SOURCE}" \
        "${MAILU_VALUES}" --create-target-namespace || exit 1

CL_DIR=`mkdir_ns ${APPS_DIR} ${TNS} ${FLUX_NS}`
NAME=${MAILU_NAME}

printf "\n$VALUES" >> "${CL_DIR}/${NAME}/${NAME}.yaml"

echo "      ${BOLD}Deploying changes${NORMAL}"

#update_repo ${NAME}

#wait_for_ready
