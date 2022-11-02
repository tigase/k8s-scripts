#!/bin/bash
#
# Script initializes cluster with FluxCD and setups basic
# git repo structure and data
#

source `dirname "$0"`/scripts-env-init.sh

MODE="FluxCD installation"

[[ "$1" == "--update" ]] && MODE="FluxCD update"

[[ "$1" != "--update" ]] && [[ -d ${CLUSTER_REPO_DIR} ]] && {
  echo "${ERROR}Local folder the cluster repository already exist: ${CLUSTER_REPO_DIR}${NORMAL}"
  echo "${ERROR}Cleanup first and then rerun the script${NORMAL}"
  exit 1
}

flux check
echo -e "    ${INFO}${MODE}\nPress ENTER if everything looks correct, Ctrl-C to stop${NORMAL}"
read abc

flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$CLUSTER_REPO \
  --branch=$REPO_BRANCH \
  --path=./clusters/$CLUSTER_NAME \
  --token-auth \
  --personal

[[ "$1" == "--update" ]] && {
  flux reconcile source git flux-system
  echo "FluxCD on the cluster updated"
  exit 0
}

if [ ! -d  "$PROJECTS_DIR" ]; then
  mkdir "$PROJECTS_DIR"
fi

cd ${PROJECTS_DIR} &> /dev/null || { echo "No projects dir!"; exit 1; }
git clone "https://github.com/$GITHUB_USER/$CLUSTER_REPO"
if [ ! -d  "$CLUSTER_REPO" ]; then
  echo "${ERROR}Failed to clone cluster repository $CLUSTER_REPO to $CLUSTER_REPO_DIR!${NORMAL}"
  exit 1;
fi
cd $CLUSTER_REPO

FILE="./clusters/${CLUSTER_NAME}/${BASE}.yaml"

[[ -f "${FILE}" ]] || cat > "${FILE}" <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: ${BASE}
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./${BASE_DIR}
  prune: true
  validation: client

EOF

mkdir -p ./${BASE_DIR}/sources

FILE="./${BASE_DIR}/kustomization.yaml"
[[ -f "${FILE}" ]] || cat > "${FILE}" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - sources
EOF

FILE="./${BASE_DIR}/sources/kustomization.yaml"
[[ -f "${FILE}" ]] || cat > "${FILE}" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: flux-system
resources:
  - chartmuseum.yaml
EOF

FILE="./${BASE_DIR}/sources/chartmuseum.yaml"
[[ -f "${FILE}" ]] || cat > "${FILE}" <<EOF
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: HelmRepository
metadata:
  name: chartmuseum
  namespace: flux-system
spec:
  interval: 30m
  url: https://helm.wso2.com
EOF

FILE="./clusters/${CLUSTER_NAME}/${APPS}.yaml"

[[ -f "${FILE}" ]] || cat > "${FILE}" <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: ${APPS}
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./${APPS_DIR}
  prune: true
  validation: client

EOF
mkdir -p ${APPS_DIR}

FILE="./${APPS_DIR}/kustomization.yaml"
[[ -f "${FILE}" ]] || cat > "${FILE}" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
EOF

update_repo "Initial"

