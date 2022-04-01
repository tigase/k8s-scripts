#!/bin/bash
#
# Script is the main entry point to setup OneDev & MySQL instances in a specified namespace.
#

source `dirname "$0"`/scripts-env-init.sh

INTERVAL="${DEF_INTERVAL}"
SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-${CLUSTER_NAME}.pem"

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "${ERROR}No cluster repo dir!${NORMAL}"; exit 1; }

echo "   ${BOLD}Deploying onedev${NORMAL}"

if [ -z "$ONEDEV_DOMAIN" ]; then
  echo "   ${ERROR}onedev domain name is not set!${NORMAL}";
  exit 1;
fi


TNS=${ONEDEV_TARGET_NAMESPACE}

${SCRIPTS}/cluster-tigase-helm-charts.sh

ONEDEV_MYSQL_PASSWORD=`gen_token 8`
ONEDEV_MYSQL_ROOT_PASSWORD=`gen_token 24`

[[ "$1" == "-q" ]] || {
  echo -n "Provide MySQL user password: "; read u_pass
  echo -n "Provide MySQL root user password: "; read u_root_pass
  [[ -z ${u_pass} ]] || ONEDEV_MYSQL_PASSWORD=${u_pass}
  [[ -z ${u_root_pass} ]] || ONEDEV_MYSQL_ROOT_PASSWORD=${u_root_pass}
}

if [ "${ONEDEV_MYSQL_S3_BACKUP}" == "true" ]; then
  if [ -z "${ONEDEV_MYSQL_S3_BACKUP_ACCESS_KEY}" ]; then
    echo -n "Provide MySQL S3 backup access-key: "; read a_key;
    echo -n "Provide MySQL S3 backup secret-key: "; read s_key;
    [[ -z ${a_key} ]] || ONEDEV_MYSQL_S3_BACKUP_ACCESS_KEY=${a_key}
    [[ -z ${s_key} ]] || ONEDEV_MYSQL_S3_BACKUP_SECRET_KEY=${s_key}
  fi
fi

echo "      ${BOLD}Preparing MySQL deployment${NORMAL}"

CL_DIR=`mkdir_ns ${APPS_DIR} ${TNS} ${FLUX_NS}`

cat > "${CL_DIR}/${TNS}.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${TNS}
EOF

MYSQL_NAME="${ONEDEV_NAME}-mysql"
NAME="${MYSQL_NAME}"

mkdir -p "${CL_DIR}/${NAME}"
kubectl create secret generic "mysql-credentials" \
    --namespace "${TNS}" \
    --from-literal=mysql-password="${ONEDEV_MYSQL_PASSWORD}" \
    --from-literal=mysql-root-password="${ONEDEV_MYSQL_ROOT_PASSWORD}" \
    --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
    --format=yaml > "${CL_DIR}/${NAME}/onedev-mysql-credentials-sealed.yaml"
   
if [ "${ONEDEV_MYSQL_S3_BACKUP}" == "true" ]; then 
  kubectl create secret generic "mysql-backup-s3" \
    --namespace "${TNS}" \
    --from-literal=access-key="${ONEDEV_MYSQL_S3_BACKUP_ACCESS_KEY}" \
    --from-literal=secret-key="${ONEDEV_MYSQL_S3_BACKUP_SECRET_KEY}" \
    --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
    --format=yaml > "${CL_DIR}/${NAME}/onedev-mysql-backup-s3-sealed.yaml"
fi

VALUES=`envsubst < ${ONEDEV_MYSQL_VALUES_FILE}`
    
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
      chart: mysql
      sourceRef:
        kind: GitRepository
        name: tigase
        namespace: flux-system
      interval: 1m
  interval: 5m
  values:
    auth:
      database: "onedev"
      username: "onedev"
      existingSecret: "mysql-credentials"

    updateStrategy: Recreate

${VALUES}
EOF

update_kustomization ${CL_DIR}/${NAME}

echo "      ${BOLD}Preparing onedev deployment${NORMAL}"

NAME="${ONEDEV_NAME}"

mkdir -p "${CL_DIR}/${NAME}"

VALUES=`envsubst < ${ONEDEV_VALUES_FILE}`

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
      chart: onedev
      sourceRef:
        kind: GitRepository
        name: tigase
        namespace: flux-system
      interval: 1m
  interval: 5m
  values:
    mysql:
      enabled: false
    externalDatabase: 
      host: "${MYSQL_NAME}"
      database: "onedev"
      user: "onedev"
      port: 3306
      existingSecret: "mysql-credentials"
          
    updateStrategy: Recreate
    
${VALUES}
EOF

update_kustomization ${CL_DIR}/${NAME}

update_kustomization ${CL_DIR}

update_kustomization ${APPS_DIR}

echo "      ${BOLD}Deploying changes${NORMAL}"

update_repo ${NAME}

wait_for_ready
