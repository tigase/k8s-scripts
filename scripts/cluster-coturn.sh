#!/bin/bash
#
# Script is the main entry point to setup CoTUNRN instances in a specified namespace.
#

source `dirname "$0"`/scripts-env-init.sh

INTERVAL="${DEF_INTERVAL}"
SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-${CLUSTER_NAME}.pem"

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "${ERROR}No cluster repo dir!${NORMAL}"; exit 1; }

echo "   ${BOLD}Deploying CoTURN${NORMAL}"

[[ "$1" == "-q" ]] || {
  echo -n "Provide CoTURN domain: "; read u_domain;
  echo -n "Provide CoTURN username: "; read u_user
  echo -n "Provide CoTURN password: "; read u_pass
  echo -n "Provide lower bound of UDP port to use for relay [40000]: "; read u_lport;
  echo -n "Provide upper bound of UDP port to use for relay [41000]: "; read u_uport;
  [[ -z ${u_domain} ]] || COTURN_DOMAIN=${u_domain}
  [[ -z ${u_user} ]] || COTURN_USERNAME=${u_user}
  [[ -z ${u_pass} ]] || COTURN_PASSWORD=${u_pass}
  [[ -z ${u_lport} ]] || COTURN_LPORT=${u_lport}
  [[ -z ${u_uport} ]] || COTURN_UPORT=${u_uport}
}

TNS=${COTURN_TARGET_NAMESPACE}

${SCRIPTS}/cluster-tigase-helm-charts.sh

CL_DIR=`mkdir_ns ${APPS_DIR} ${TNS} ${FLUX_NS}`

cat > "${CL_DIR}/${TNS}.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${TNS}
EOF

NAME="${COTURN_NAME}"

mkdir -p "${CL_DIR}/${NAME}"

VALUES=`export COTURN_DOMAIN="${COTURN_DOMAIN}" COTURN_USERNAME="${COTURN_USERNAME}" COTURN_PASSWORD="${COTURN_PASSWORD}" COTURN_LPORT="${COTURN_LPORT}" COTURN_UPORT="${COTURN_UPORT}"  && envsubst < ${COTURN_VALUES_FILE}`

cat > "${CL_DIR}/${NAME}/${NAME}.yaml" << EOF
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: ${NAME}
  namespace: ${TNS}
spec:
  releaseName: ${NAME}
  chart:
    spec:
      chart: coturn
      sourceRef:
        kind: GitRepository
        name: tigase
        namespace: flux-system
      interval: 1m
  interval: 5m
  values:
${VALUES}
EOF

update_kustomization ${CL_DIR}/${NAME}

update_kustomization ${CL_DIR}

update_kustomization ${APPS_DIR}

# update_repo ${NAME}

wait_for_ready

