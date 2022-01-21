#!/bin/bash
# 
# Script deploys cert manager and sets it up to use letsencrypt to
# generate certificates for requested services
#

source ~/envs/cluster.env || exit 1
source ~/envs/versions.env || exit 1
source ${SCRIPTS}/cluster-tools.sh || exit 1

NAME="${CM_NAME}"
TNS="${CM_TARGET_NAMESPACE}"
cd ${CLUSTER_REPO_DIR}

CL_DIR=`mkdir_ns ${BASE_DIR} ${TNS} ${FLUX_NS}`

echo "Deploying ${NAME}"
~/scripts/flux-create-helmrel.sh \
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

update_kustomization ${CL_DIR}/${NAME}

update_repo "${NAME}"

