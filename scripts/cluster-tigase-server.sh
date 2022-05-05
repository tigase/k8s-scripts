#!/bin/bash
#
# Script is the main entry point to setup Tigase & MySQL instances in a specified namespace.
#

source `dirname "$0"`/scripts-env-init.sh

INTERVAL="${DEF_INTERVAL}"
SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-${CLUSTER_NAME}.pem"

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "${ERROR}No cluster repo dir!${NORMAL}"; exit 1; }

echo "   ${BOLD}Deploying Tigase${NORMAL}"

TNS=${TIGASE_TARGET_NAMESPACE}

${SCRIPTS}/cluster-tigase-helm-charts.sh

TIGASE_MYSQL_PASSWORD=`gen_token 8`
TIGASE_MYSQL_ROOT_PASSWORD=`gen_token 24`

[[ "$1" == "-q" ]] || {
  echo -n "Provide MySQL user password: "; read u_pass
  echo -n "Provide MySQL root user password: "; read u_root_pass
  [[ -z ${u_pass} ]] || TIGASE_MYSQL_PASSWORD=${u_pass}
  [[ -z ${u_root_pass} ]] || TIGASE_MYSQL_ROOT_PASSWORD=${u_root_pass}
}

if [ -z "${TIGASE_MYSQL_S3_BACKUP}" ]; then
  echo -n "Enable MySQL backup to S3: "; read e_key;
  [[ -z ${e_key} ]] || TIGASE_MYSQL_S3_BACKUP=${e_key}
  if [ "true" == "${e_key}" ]; then
    echo -n "Provide MySQL S3 backup endpoint: "; read e_key;
    echo -n "Provide MySQL S3 backup bucket: "; read b_key;
    echo -n "Provide MySQL S3 backup prefix: "; read p_key;
    echo -n "Provide MySQL S3 backup access-key: "; read a_key;
    echo -n "Provide MySQL S3 backup secret-key: "; read s_key;
    echo -n "Provide MySQL S3 backup schedule: "; read sc_key;
    echo -n "Provide MySQL S3 backup expire in: "; read ei_key;
    [[ -z ${e_key} ]] || TIGASE_MYSQL_S3_BACKUP_ENDPOINT=${e_key};
    [[ -z ${b_key} ]] || TIGASE_MYSQL_S3_BACKUP_BUCKET=${b_key};
    [[ -z ${p_key} ]] || TIGASE_MYSQL_S3_BACKUP_PREFIX=${p_key};
    [[ -z ${a_key} ]] || TIGASE_MYSQL_S3_BACKUP_ACCESS_KEY=${a_key}
    [[ -z ${s_key} ]] || TIGASE_MYSQL_S3_BACKUP_SECRET_KEY=${s_key}
    [[ -z ${sc_key} ]] || TIGASE_MYSQL_S3_BACKUP_SCHEDULE=${sc_key}
    [[ -z ${ei_key} ]] || TIGASE_MYSQL_S3_BACKUP_EXPIRE_IN=${ei_key}
  fi
fi

if [ -z "${TIGASE_DOMAIN}" ]; then
  echo -n "Provide Tigase default domain: "; read a_key;
  [[ -z ${a_key} ]] || TIGASE_DOMAIN=${a_key}
fi

if [ -z "${TIGASE_S3_UPLOAD_ENDPOINT}" ]; then
  echo -n "Provide Tigase S3 upload endpoint: "; read a_key;
  [[ -z ${a_key} ]] || TIGASE_S3_UPLOAD_ENDPOINT=${a_key};
fi

if [ -z "${TIGASE_S3_UPLOAD_ACCESS_KEY}" ]; then
  echo -n "Provide Tigase S3 upload access-key: "; read a_key;
  echo -n "Provide Tigase S3 upload secret-key: "; read s_key;
  [[ -z ${a_key} ]] || TIGASE_S3_UPLOAD_ACCESS_KEY=${a_key}
  [[ -z ${s_key} ]] || TIGASE_S3_UPLOAD_SECRET_KEY=${s_key}
fi

if [ -z "${TIGASE_S3_UPLOAD_BUCKET}" ]; then
  echo -n "Provide Tigase S3 upload bucket: "; read a_key;
  [[ -z ${a_key} ]] || TIGASE_S3_UPLOAD_BUCKET=${a_key};
fi

if [ -z "${TIGASE_S3_UPLOAD_PATH_STYLE}" ]; then
  echo -n "Provide Tigase S3 upload path style: "; read a_key;
  [[ -z ${a_key} ]] || TIGASE_S3_UPLOAD_PATH_STYLE=${a_key};
fi

echo "      ${BOLD}Preparing MySQL deployment${NORMAL}"

CL_DIR=`mkdir_ns ${APPS_DIR} ${TNS} ${FLUX_NS}`

cat > "${CL_DIR}/${TNS}.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${TNS}
EOF

MYSQL_NAME="${TIGASE_NAME}-mysql"
NAME="${MYSQL_NAME}"

mkdir -p "${CL_DIR}/${NAME}"
kubectl create secret generic "mysql-credentials" \
    --namespace "${TNS}" \
    --from-literal=mysql-password="${TIGASE_MYSQL_PASSWORD}" \
    --from-literal=mysql-root-password="${TIGASE_MYSQL_ROOT_PASSWORD}" \
    --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
    --format=yaml > "${CL_DIR}/${NAME}/tigase-mysql-credentials-sealed.yaml"
   
if [ "${TIGASE_MYSQL_S3_BACKUP}" == "true" ]; then 
  kubectl create secret generic "mysql-backup-s3" \
    --namespace "${TNS}" \
    --from-literal=access-key="${TIGASE_MYSQL_S3_BACKUP_ACCESS_KEY}" \
    --from-literal=secret-key="${TIGASE_MYSQL_S3_BACKUP_SECRET_KEY}" \
    --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
    --format=yaml > "${CL_DIR}/${NAME}/tigase-mysql-backup-s3-sealed.yaml"
fi

VALUES=`export TIGASE_MYSQL_S3_BACKUP="${TIGASE_MYSQL_S3_BACKUP}" TIGASE_MYSQL_S3_BACKUP_ENDPOINT="${TIGASE_MYSQL_S3_BACKUP_ENDPOINT}" TIGASE_MYSQL_S3_BACKUP_BUCKET="${TIGASE_MYSQL_S3_BACKUP_BUCKET}" TIGASE_MYSQL_S3_BACKUP_PREFIX="${TIGASE_MYSQL_S3_BACKUP_PREFIX}" TIGASE_MYSQL_S3_BACKUP_ACCESS_KEY="${TIGASE_MYSQL_S3_BACKUP_ACCESS_KEY}" TIGASE_MYSQL_S3_BACKUP_SCHEDULE="${TIGASE_MYSQL_S3_BACKUP_SCHEDULE}" TIGASE_MYSQL_S3_BACKUP_EXPIRE_IN="${TIGASE_MYSQL_S3_BACKUP_EXPIRE_IN}" && envsubst < ${TIGASE_MYSQL_VALUES_FILE}`
    
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
      database: "tigase"
      username: "tigase"
      existingSecret: "mysql-credentials"

    updateStrategy: Recreate

${VALUES}
EOF

update_kustomization ${CL_DIR}/${NAME}

echo "      ${BOLD}Preparing Tigase deployment${NORMAL}"

NAME="${TIGASE_NAME}"

mkdir -p "${CL_DIR}/${NAME}"

if [ "${TIGASE_S3_UPLOAD}" == "true" ]; then
  kubectl create secret generic "tigase-s3-upload" \
    --namespace "${TNS}" \
    --from-literal="${TIGASE_S3_UPLOAD_ACCESS_KEY}"="${TIGASE_S3_UPLOAD_SECRET_KEY}" \
    --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
    --format=yaml > "${CL_DIR}/${NAME}/tigase-s3-upload-sealed.yaml"
fi

VALUES=`export TIGASE_S3_UPLOAD_ACCESS_KEY="${TIGASE_S3_UPLOAD_ACCESS_KEY}" TIGASE_DOMAIN="${TIGASE_DOMAIN}" TIGASE_S3_UPLOAD_ENDPOINT="${TIGASE_S3_UPLOAD_ENDPOINT}" TIGASE_S3_UPLOAD_PATH_STYLE="${TIGASE_S3_UPLOAD_PATH_STYLE}" && envsubst < ${TIGASE_VALUES_FILE}`

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
      chart: tigase-xmpp-server
      sourceRef:
        kind: GitRepository
        name: tigase
        namespace: flux-system
      interval: 1m
  interval: 5m
  values:
    database:
      type: "mysql"
      host: "tigase-server-mysql"
      user: "tigase"
      secret: "mysql-credentials"
      secretPasswordKey: "mysql-password"

    updateStrategy: Recreate
    
${VALUES}
EOF

update_kustomization ${CL_DIR}/${NAME}

update_kustomization ${CL_DIR}

update_kustomization ${APPS_DIR}

INGRESS_DIR=`mkdir_ns ${BASE_DIR} ${IN_TARGET_NAMESPACE} ${FLUX_NS}`

sed -i'' -e "s#    tcp:#    tcp:\n        \!\!str 8080: \"${TNS}/${NAME}-tigase-xmpp-server:8080\"#" "${INGRESS_DIR}/${IN_NAME}/${IN_NAME}.yaml"
sed -i'' -e "s#    tcp:#    tcp:\n        \!\!str 5291: \"${TNS}/${NAME}-tigase-xmpp-server:5291\"#" "${INGRESS_DIR}/${IN_NAME}/${IN_NAME}.yaml"
sed -i'' -e "s#    tcp:#    tcp:\n        \!\!str 5290: \"${TNS}/${NAME}-tigase-xmpp-server:5290\"#" "${INGRESS_DIR}/${IN_NAME}/${IN_NAME}.yaml"
sed -i'' -e "s#    tcp:#    tcp:\n        \!\!str 5280: \"${TNS}/${NAME}-tigase-xmpp-server:5280\"#" "${INGRESS_DIR}/${IN_NAME}/${IN_NAME}.yaml"
sed -i'' -e "s#    tcp:#    tcp:\n        \!\!str 5269: \"${TNS}/${NAME}-tigase-xmpp-server:5269\"#" "${INGRESS_DIR}/${IN_NAME}/${IN_NAME}.yaml"
sed -i'' -e "s#    tcp:#    tcp:\n        \!\!str 5223: \"${TNS}/${NAME}-tigase-xmpp-server:5223\"#" "${INGRESS_DIR}/${IN_NAME}/${IN_NAME}.yaml"
sed -i'' -e "s#    tcp:#    tcp:\n        \!\!str 5222: \"${TNS}/${NAME}-tigase-xmpp-server:5222\"#" "${INGRESS_DIR}/${IN_NAME}/${IN_NAME}.yaml"


echo "      ${BOLD}Deploying changes${NORMAL}"

update_repo ${NAME}

wait_for_ready

