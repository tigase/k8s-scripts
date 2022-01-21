#!/bin/bash
#
# Scripts installs k8s dashboard service and stores access token
# in a local FS file
#

source ~/envs/cluster.env || exit 1
source ~/envs/versions.env || exit 1
source ${SCRIPTS}/cluster-tools.sh || exit 1

NAME=${DA_NAME}
TNS=${DA_TARGET_NAMESPACE}
DA_USER="dashboard-admin"

cd ${CLUSTER_REPO_DIR}

CL_DIR=`mkdir_ns ${BASE_DIR} ${TNS} ${FLUX_NS}`

mkdir -p "${CL_DIR}/${NAME}"

cat > "${CL_DIR}/${NAME}/dashboard-service-account.yaml" <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${DA_USER}
  namespace: ${DA_TARGET_NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${DA_USER}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: ${DA_USER}
    namespace: ${DA_TARGET_NAMESPACE}
EOF

echo "Deploying ${NAME}"
~/scripts/flux-create-helmrel.sh \
        "${DA_NAME}" \
        "${DA_VER}" \
        "${DA_RNAME}" \
        "${DA_TARGET_NAMESPACE}" \
        "${DA_NAMESPACE}" \
        "${DA_SOURCE}" \
        "${DA_VALUES}" --create-target-namespace || exit 1

update_chart_ns "${CL_DIR}/${NAME}/${NAME}.yaml"

update_repo ${NAME}

wait_for_ready

DA_TOKEN=`kubectl -n ${DA_TARGET_NAMESPACE} get secret \
  $(kubectl -n ${DA_TARGET_NAMESPACE} get sa/${DA_USER} -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"`

update_k8s_secrets "dashboard-token" "${DA_TOKEN}"

