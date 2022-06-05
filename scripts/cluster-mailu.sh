#!/bin/bash
#
# Script deploys Mailu on the k8s cluster.
#

source `dirname "$0"`/scripts-env-init.sh

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "${ERROR}No cluster repo dir!${NORMAL}"; exit 1; }

CL_SERV_NAME=${MAILU_NAME}
CL_SERV_TNS=${MAILU_TARGET_NAMESPACE}
CL_SERV_TYPE=${APPS}

source ${SCRIPTS}/cluster-script-preprocess.sh $1

source "${CONFIG}/envs/mailu.env"

INTERVAL="${DEF_INTERVAL}"
SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-${CLUSTER_NAME}.pem"

TNS=${MAILU_TARGET_NAMESPACE}

if [ -z "${MAILU_DOMAIN}" ]; then
  echo -n "Provide domain: "; read h_key;
  [[ -z ${h_key} ]] || MAILU_DOMAIN=${h_key}
fi

if [ -z "${MAILU_HOSTNAMES}" ]; then
  MAILU_HOSTNAMES=()
  while : ; do 
    echo -n "Provide hostname to host emails for, or empty to continue: "; read d_key;
    if [[ -z ${d_key} ]]; then
      break;
    else
      idx=$(( ${#MAILU_HOSTNAMES[@]} + 1 ));
      MAILU_HOSTNAMES[${idx}]="${d_key}";
        echo "Hostnames: $idx"
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

if [ -z "${MAILU_SUBNET}" ]; then
  echo -n "Provide subnet from which to allow to accept connections: "; read s_key;
  [[ -z ${s_key} ]] || MAILU_SUBNET=${s_key}
fi 

if [ -z "${MAILU_RELAY_HOST}" ]; then
  echo -n "Provide relay host for sending outgoing emails: "; read h_key;
  [[ -z ${h_key} ]] || MAILU_RELAY_HOST=${h_key}
fi

if [ ! -z "${MAILU_RELAY_HOST}" ]; then
  if [ -z "${MAILU_RELAY_USERNAME}" ]; then
	echo -n "Provide relay username: "; read u_key;
	[[ -z ${u_key} ]] || MAILU_RELAY_USERNAME=${u_key}
  fi
  
  if [ ! -z "${MAILU_RELAY_USERNAME}" ]; then
    if [ -z "${MAILU_RELAY_PASSWORD}" ]; then
	  echo -n "Provide relay password: "; read p_key;
	  [[ -z ${p_key} ]] || MAILU_RELAY_PASSWORD=${p_key}
    fi
  fi
fi

if [ -z "${MAILU_SECRET_KEY}" ]; then
  MAILU_SECRET_KEY=`gen_token 16`
fi

HOSTNAMES_COUNT=${#MAILU_HOSTNAMES[@]}
if [ $HOSTNAMES_COUNT == 0 ]; then
	echo "No hostnames!"
	exit 1
fi

VALUES=$"    subnet: ${MAILU_SUBNET}"
VALUES="$VALUES\n    secretKey: \"${MAILU_SECRET_KEY}\"\n    domain: \"$MAILU_DOMAIN\"\n    hostnames:"
for vhost in "${MAILU_HOSTNAMES[@]}"
do
  echo "$i"
  VALUES=$"$VALUES\n      - \"$vhost\""
done 

VALUES="$VALUES\n    initialAccount:"
VALUES="$VALUES\n      username: \"${MAILU_ADMIN_USERNAME}\""
VALUES="$VALUES\n      domain: \"${MAILU_ADMIN_DOMAIN}\""
VALUES="$VALUES\n      password: \"${MAILU_ADMIN_PASSWORD}\""
if [ ! -z "${MAILU_RELAY_HOST}" ]; then
  VALUES="$VALUES\n    external_relay:"
  VALUES="$VALUES\n      host: \"${MAILU_RELAY_HOST}\""
  if [ ! -z "${MAILU_RELAY_USERNAME}" ]; then
    VALUES="$VALUES\n      username: \"${MAILU_RELAY_USERNAME}\""
  fi
  if [ ! -z "${MAILU_RELAY_PASSWORD}" ]; then
    VALUES="$VALUES\n      password: \"${MAILU_RELAY_PASSWORD}\""
  fi
fi

echo "      ${BOLD}Adding Mailu helm chart${NORMAL}"

${SCRIPTS}/flux-create-source.sh ${MAILU_S_NAME} ${MAILU_URL}

update_kustomization ${BASE_DIR}/sources

NAME="${MAILU_NAME}"

echo "      ${BOLD}Preparing Mailu deployment${NORMAL}"

[ "${MAILU_EXISTING_PVC}" == "true" ] && {

  echo "      ${BOLD}Creating namespace${NORMAL}"
  CL_DIR=`create_ns ${APPS_DIR} ${MAILU_TARGET_NAMESPACE}`
  update_kustomization `dirname ${CL_DIR}`
  update_kustomization ${CL_DIR}

  [ "${1}" == "--update" ] || {

    update_repo ${NAME}
    sleep 20

    echo "      ${BOLD}${MAILU_TARGET_NAMESPACE} namespace is prepared, you can now create PVC: mailu-pvc${NORMAL}"
    echo "      ${BOLD}for mailu deployment. Press enter when ready.${NORMAL}"
    read abc

    #echo "      ${BOLD}Prepare PVCs${NORMAL}"

    #${SCRIPTS}/create-longhorn-pvc.sh mailu-pvc ${MAILU_TARGET_NAMESPACE} 20Gi ${CL_DIR}
    #update_kustomization ${CL_DIR}
    #update_repo ${NAME}
    #sleep 30

    #exit 1

  }

}

MAILU_VALUES=""
${SCRIPTS}/flux-create-helmrel.sh app \
        "${MAILU_NAME}" \
        "${MAILU_VER}" \
        "${MAILU_RNAME}" \
        "${MAILU_TARGET_NAMESPACE}" \
        "${MAILU_NAMESPACE}" \
        "${MAILU_SOURCE}" \
        "${MAILU_VALUES}" --create-target-namespace || exit 1

CL_DIR=`mkdir_ns ${APPS_DIR} ${TNS} ${FLUX_NS}`

update_chart_ns "${CL_DIR}/${NAME}/${NAME}.yaml"

yq e -i ".spec.timeout = \"${MAILU_FLUXCD_TIMEOUT}\"" "${CL_DIR}/${NAME}/${NAME}.yaml"
yq e -i ".spec.install.timeout = \"${MAILU_FLUXCD_TIMEOUT}\"" "${CL_DIR}/${NAME}/${NAME}.yaml"
#yq e -i '.spec.install.disableWait = true' "${CL_DIR}/${NAME}/${NAME}.yaml"
#yq e -i '.spec.secretRef.name = "regcred"' "${CL_DIR}/${NAME}/${NAME}.yaml"
#yq e -i '.spec.accessFrom."namespaceSelectors"[0].matchLabels."kubernetes.io/metadata.name" = "flux-system"' "${CL_DIR}/${NAME}/${NAME}.yaml"

echo -e "  values:" >> "${CL_DIR}/${NAME}/${NAME}.yaml"

cat "${CONFIG}/envs/${MAILU_NAME}-values.yaml" >> "${CL_DIR}/${NAME}/${NAME}.yaml"

printf "$VALUES" >> "${CL_DIR}/${NAME}/${NAME}.yaml"

[ "$1" == "--no-commit" ] || [ "$2" == "--no-commit" ] || {

  echo "      ${BOLD}Deploying changes${NORMAL}"

  update_repo ${NAME}

  wait_for_ready

  [ -z "${MAILU_AWS_ZONE_ID}" ] || {
    echo "      ${BOLD}Updating DNS for ${MAILU_HOSTNAMES[0]} and ${MAILU_DOMAIN} ${NORMAL}"
    HOSTNAME_IP=`kubectl get ingress -n mailu-prod mailu-ingress -o jsonpath='{.status.loadBalancer.ingress[].ip}'`
    SERVER_IP=`kubectl get svc -n mailu-prod mailu-front-ext -o jsonpath='{.status.loadBalancer.ingress[].ip}'`
    echo "Setting ${MAILU_HOSTNAMES[0]} -> ${HOSTNAME_IP} and ${MAILU_DOMAIN} -> ${SERVER_IP}"
    ${SCRIPTS}/aws-update-zone.sh "${MAILU_AWS_ZONE_ID}" "${MAILU_DOMAIN}" "${SERVER_IP}" "${MAILU_HOSTNAMES[0]}" "${HOSTNAME_IP}"
  }
}
