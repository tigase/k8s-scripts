#!/bin/bash
#
# Script is the main entry point to setup Rancher in a specified namespace.
#

source `dirname "$0"`/scripts-env-init.sh

INTERVAL="${DEF_INTERVAL}"
SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-${CLUSTER_NAME}.pem"

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "${ERROR}No cluster repo dir!${NORMAL}"; exit 1; }

${SCRIPTS}/flux-create-source.sh ${RANCHER_S_NAME} ${RANCHER_URL}

echo "   ${BOLD}Deploying Rancher${NORMAL}"

TNS=${RANCHER_TARGET_NAMESPACE}

[[ "$1" == "-q" ]] || {
  echo -n "Provide Rancher admin password: "; read u_pass
  echo -n "Provide Rancher hostname: "; read u_hostname
  [[ -z ${u_pass} ]] || RANCHER_PASSWORD=${u_pass}
  [[ -z ${u_hostname} ]] || RANCHER_HOSTNAME=${u_hostname}
}

CL_DIR=`mkdir_ns ${APPS_DIR} ${TNS} ${FLUX_NS}`

NAME="${RANCHER_NAME}"

cat > "${CL_DIR}/${TNS}.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${TNS}
EOF

mkdir -p "${CL_DIR}/${NAME}"

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
      chart: rancher
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: rancher
        namespace: flux-system
      version: ${RANCHER_VER}
  interval: 1h0m0s
  values:
    hostname: "${RANCHER_HOSTNAME}"
    ingress:
      tls:
        source: letsEncrypt
    letsEncrypt:
      email: "${SSL_EMAIL}"
      ingress:
        class: nginx
    bootstrapPassword: "${RANCHER_PASSWORD}"
EOF

update_kustomization ${CL_DIR}/${NAME}

update_kustomization ${CL_DIR}

update_kustomization ${APPS_DIR}

echo "      ${BOLD}Deploying changes${NORMAL}"

update_repo ${NAME}

wait_for_ready