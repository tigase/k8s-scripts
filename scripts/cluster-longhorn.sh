#!/bin/bash
# 
# Scripts deploys longhorn to the cluster with some basic configuration
# Web access is protected with user name and password. Both username
# and password are generated during the script runtime using pwgen
# and stored in the local filesystem for admin to use
# Username and password are also stored in the Longhorn metadata 
# configuration encrypted using sealed secrets
#

source ~/envs/cluster.env || exit 1
source ~/envs/versions.env || exit 1
source ${SCRIPTS}/cluster-tools.sh || exit 1

NAME="${LH_NAME}"
TNS=${LH_TARGET_NAMESPACE}
SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-${CLUSTER_NAME}.pem"
USER_NAME=`gen_token 8`
USER_PASS=`gen_token 24`

[[ "$1" == "-q" ]] || {
  echo -n "Provide Longhorn user name: "; read u_name
  echo -n "Provide Longhorn user password: "; read u_pass
  [[ -z ${u_name} ]] || USER_NAME=${u_name}
  [[ -z ${u_pass} ]] || USER_PASS=${u_pass}
}
update_k8s_secrets "longhorn-user" ${USER_NAME}
update_k8s_secrets "longhorn-pass" ${USER_PASS}

SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-${CLUSTER_NAME}.pem"
source ${HOME}/.oci/k8stests-secrets-keys || exit 1
S3_SECRET_KEY="${secret_key}"
S3_ACCESS_KEY="${access_key}"

cd ${CLUSTER_REPO_DIR}

CL_DIR=`mkdir_ns ${BASE_DIR} ${TNS} ${FLUX_NS}`

mkdir -p "${CL_DIR}/${NAME}"

kubectl create secret generic "s3-secrets" \
    --namespace "${LH_TARGET_NAMESPACE}" \
    --from-literal=AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY}" \
    --from-literal=AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}" \
    --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
    --format=yaml > "${CL_DIR}/${NAME}/s3-secrets-sealed.yaml"


echo "Deploying ${NAME}"
~/scripts/flux-create-helmrel.sh \
        "${LH_NAME}" \
        "${LH_VER}" \
        "${LH_RNAME}" \
        "${LH_TARGET_NAMESPACE}" \
        "${LH_NAMESPACE}" \
        "${LH_SOURCE}" \
        "${LH_VALUES}" --create-target-namespace --depends-on="${FLUX_NS}/${SS_NAME}" || exit 1

update_chart_ns "${CL_DIR}/${NAME}/${NAME}.yaml"

update_repo ${NAME}

wait_for_ready

rm -f ${HOME}/auth
echo "${USER_NAME}:$(openssl passwd -stdin -apr1 <<< ${USER_PASS})" >> ${HOME}/auth
cat ${HOME}/auth
kubectl -n longhorn-system create secret generic basic-auth --from-file=${HOME}/auth
kubectl -n longhorn-system get secret basic-auth -o yaml > ${HOME}/.kube/longhorn-basic-auth.yaml

cat >> "${CL_DIR}/${NAME}/${NAME}-ingress.yaml" <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ingress
  namespace: longhorn-system
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/ssl-redirect: 'false'
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required '
spec:
  defaultBackend:
    service:
      name: longhorn-frontend
      port:
        number: 80
  rules:
  - http:
      paths:
      - pathType: Prefix
        path: "/lh/"
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
EOF

update_kustomization "${CL_DIR}/${NAME}"

update_repo ${NAME}

