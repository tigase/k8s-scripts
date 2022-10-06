#!/bin/bash
#
# Script is the main entry point to setup KillBill & MySQL instances in a specified namespace.
#

source `dirname "$0"`/scripts-env-init.sh

INTERVAL="${DEF_INTERVAL}"
SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-${CLUSTER_NAME}.pem"

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "${ERROR}No cluster repo dir!${NORMAL}"; exit 1; }

echo "   ${BOLD}Deploying KillBill${NORMAL}"

TNS=${KILLBILL_TARGET_NAMESPACE}

${SCRIPTS}/cluster-tigase-helm-charts.sh

KILLBILL_MYSQL_PASSWORD=`gen_token 8`
KILLBILL_MYSQL_ROOT_PASSWORD=`gen_token 24`

[[ "$1" == "-q" ]] || {
  echo -n "Provide MySQL user password: "; read u_pass
  echo -n "Provide MySQL root user password: "; read u_root_pass
  [[ -z ${u_pass} ]] || KILLBILL_MYSQL_PASSWORD=${u_pass}
  [[ -z ${u_root_pass} ]] || KILLBILL_MYSQL_ROOT_PASSWORD=${u_root_pass}
}

if [ -z "${KILLBILL_MYSQL_S3_BACKUP}" ]; then
  echo -n "Enable MySQL backup to S3: "; read e_key;
  [[ -z ${e_key} ]] || KILLBILL_MYSQL_S3_BACKUP=${e_key}
  if [ "true" == "${e_key}" ]; then
    echo -n "Provide MySQL S3 backup endpoint: "; read e_key;
    echo -n "Provide MySQL S3 backup bucket: "; read b_key;
    echo -n "Provide MySQL S3 backup prefix: "; read p_key;
    echo -n "Provide MySQL S3 backup access-key: "; read a_key;
    echo -n "Provide MySQL S3 backup secret-key: "; read s_key;
    echo -n "Provide MySQL S3 backup schedule: "; read sc_key;
    echo -n "Provide MySQL S3 backup expire in: "; read ei_key;
    [[ -z ${e_key} ]] || KILLBILL_MYSQL_S3_BACKUP_ENDPOINT=${e_key};
    [[ -z ${b_key} ]] || KILLBILL_MYSQL_S3_BACKUP_BUCKET=${b_key};
    [[ -z ${p_key} ]] || KILLBILL_MYSQL_S3_BACKUP_PREFIX=${p_key};
    [[ -z ${a_key} ]] || KILLBILL_MYSQL_S3_BACKUP_ACCESS_KEY=${a_key}
    [[ -z ${s_key} ]] || KILLBILL_MYSQL_S3_BACKUP_SECRET_KEY=${s_key}
    [[ -z ${sc_key} ]] || KILLBILL_MYSQL_S3_BACKUP_SCHEDULE=${sc_key}
    [[ -z ${ei_key} ]] || KILLBILL_MYSQL_S3_BACKUP_EXPIRE_IN=${ei_key}
  fi
fi

if [ -z "${KILLBILL_DOMAIN}" ]; then
  echo -n "Provide KillBill default domain: "; read a_key;
  [[ -z ${a_key} ]] || KILLBILL_DOMAIN=${a_key}
fi

if [ -z "${KAUI_DOMAIN}" ]; then
  echo -n "Provide KAUI default domain: "; read a_key;
  [[ -z ${a_key} ]] || KAUI_DOMAIN=${a_key}
fi

echo "      ${BOLD}Preparing MySQL deployment${NORMAL}"

CL_DIR=`mkdir_ns ${APPS_DIR} ${TNS} ${FLUX_NS}`

cat > "${CL_DIR}/${TNS}.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${TNS}
EOF

MYSQL_NAME="${KILLBILL_NAME}-mysql"
NAME="${MYSQL_NAME}"

mkdir -p "${CL_DIR}/${NAME}"
kubectl create secret generic "mysql-credentials" \
    --namespace "${TNS}" \
    --from-literal=mysql-password="${KILLBILL_MYSQL_PASSWORD}" \
    --from-literal=mysql-root-password="${KILLBILL_MYSQL_ROOT_PASSWORD}" \
    --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
    --format=yaml > "${CL_DIR}/${NAME}/killbill-mysql-credentials-sealed.yaml"
   
if [ "${KILLBILL_MYSQL_S3_BACKUP}" == "true" ]; then 
  kubectl create secret generic "mysql-backup-s3" \
    --namespace "${TNS}" \
    --from-literal=access-key="${KILLBILL_MYSQL_S3_BACKUP_ACCESS_KEY}" \
    --from-literal=secret-key="${KILLBILL_MYSQL_S3_BACKUP_SECRET_KEY}" \
    --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
    --format=yaml > "${CL_DIR}/${NAME}/killbill-mysql-backup-s3-sealed.yaml"
fi

VALUES=`export KILLBILL_MYSQL_S3_BACKUP="${KILLBILL_MYSQL_S3_BACKUP}" KILLBILL_MYSQL_S3_BACKUP_ENDPOINT="${KILLBILL_MYSQL_S3_BACKUP_ENDPOINT}" KILLBILL_MYSQL_S3_BACKUP_BUCKET="${KILLBILL_MYSQL_S3_BACKUP_BUCKET}" KILLBILL_MYSQL_S3_BACKUP_PREFIX="${KILLBILL_MYSQL_S3_BACKUP_PREFIX}" KILLBILL_MYSQL_S3_BACKUP_ACCESS_KEY="${KILLBILL_MYSQL_S3_BACKUP_ACCESS_KEY}" KILLBILL_MYSQL_S3_BACKUP_SCHEDULE="${KILLBILL_MYSQL_S3_BACKUP_SCHEDULE}" KILLBILL_MYSQL_S3_BACKUP_EXPIRE_IN="${KILLBILL_MYSQL_S3_BACKUP_EXPIRE_IN}" && envsubst < ${KILLBILL_MYSQL_VALUES_FILE}`
    
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
      database: "killbill"
      username: "killbill"
      existingSecret: "mysql-credentials"

    updateStrategy: Recreate

${VALUES}
EOF

update_kustomization ${CL_DIR}/${NAME}

echo "      ${BOLD}Preparing KillBill deployment${NORMAL}"

NAME="${KILLBILL_NAME}"

mkdir -p "${CL_DIR}/${NAME}"

VALUES=`export KILLBILL_DOMAIN="${KILLBILL_DOMAIN}" KAUI_DOMAIN="${KAUI_DOMAIN}" KILLBILL_DATABASE_HOST="${MYSQL_NAME}" && envsubst < ${KILLBILL_VALUES_FILE}`

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
      chart: killbill
      sourceRef:
        kind: GitRepository
        name: tigase
        namespace: flux-system
      interval: 1m
  interval: 5m
  values:
    updateStrategy: Recreate
    
${VALUES}
EOF

update_kustomization ${CL_DIR}/${NAME}

update_kustomization ${CL_DIR}

update_kustomization ${APPS_DIR}

echo "      ${BOLD}Deploying changes${NORMAL}"

update_repo ${NAME}
 
wait_for_ready

