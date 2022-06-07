#!/bin/bash
# 
# Script deploys cert manager and sets it up to use letsencrypt to
# generate certificates for requested services
#

source `dirname "$0"`/scripts-env-init.sh

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "No cluster repo dir!"; exit 1; }

CL_SERV_NAME=${CM_NAME}
CL_SERV_TNS=${CM_TARGET_NAMESPACE}
CL_SERV_TYPE=${BASE}

source ${SCRIPTS}/cluster-script-preprocess.sh $1

name="${CM_S_NAME}"
url="${CM_URL}"

echo "      ${BOLD}Adding ${name} source at ${url}${NORMAL}"
${SCRIPTS}/flux-create-source.sh ${name} ${url}
update_repo "${CM_NAME}"
wait_for_ready 5

NAME="${CM_NAME}"
TNS="${CM_TARGET_NAMESPACE}"

CL_DIR=`mkdir_ns ${BASE_DIR} ${TNS} ${FLUX_NS}`

echo "   ${BOLD}Deploying ${NAME}${NORMAL}"
${SCRIPTS}/flux-create-helmrel.sh \
        "${CM_NAME}" \
        "${CM_VER}" \
        "${CM_RNAME}" \
        "${CM_TARGET_NAMESPACE}" \
        "${CM_NAMESPACE}" \
        "${CM_SOURCE}" \
        "${CM_VALUES}" --create-target-namespace --crds=CreateReplace || exit 1

update_chart_ns "${CL_DIR}/${NAME}/${NAME}.yaml"

update_repo "${NAME}"

wait_for_ready

cat > "${CL_DIR}/${NAME}/issuer-staging.yaml" <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${SSL_STAG_ISSUER}
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${SSL_EMAIL}
    privateKeySecretRef:
      name: ${SSL_STAG_ISSUER}
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

cat > "${CL_DIR}/${NAME}/issuer-production.yaml" <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${SSL_PROD_ISSUER}
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${SSL_EMAIL}
    privateKeySecretRef:
      name: ${SSL_PROD_ISSUER}
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

[ -z "${ROUTE53_ACCESS_KEY}" ] || {

  cat > "${CL_DIR}/${NAME}/issuer-production-dns.yaml" <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${SSL_PROD_ISSUER}-dns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${SSL_EMAIL}
    privateKeySecretRef:
      name: ${SSL_PROD_ISSUER}-dns
    solvers:
      - dns01:
          route53:
            region: us-east-1
            accessKeyID: ${ROUTE53_ACCESS_KEY}
            secretAccessKeySecretRef:
              name: route53-secret
              key: secret-access-key
EOF

  SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-${CLUSTER_NAME}.pem"
  kubectl create secret generic "route53-secret" \
        --namespace "${CM_TARGET_NAMESPACE}" \
      --from-literal=secret-access-key="${ROUTE53_SECRET_KEY}" \
      --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
      --format=yaml > "${CL_DIR}/${NAME}/route53-secret.yaml"
  kubectl apply -f "${CL_DIR}/${NAME}/route53-secret.yaml"

}

update_kustomization ${CL_DIR}/${NAME}

update_repo "${NAME}"

