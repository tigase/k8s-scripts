#!/bin/bash
#
# Script adds Tigase Helm charts if not present.
#

source `dirname "$0"`/scripts-env-init.sh

INTERVAL="${DEF_INTERVAL}"
SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-${CLUSTER_NAME}.pem"

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "${ERROR}No cluster repo dir!${NORMAL}"; exit 1; }


if [ ! -f "${BASE_DIR}/sources/tigase-git.yaml" ]; then

echo "      ${BOLD}Adding tigase helm chart${NORMAL}"

cat > "${BASE_DIR}/sources/tigase-git.yaml" << EOF
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
  name: tigase
  namespace: flux-system
spec:
  interval: ${INTERVAL}
  url: https://github.com/tigase/helm-charts
  ref:
    branch: master
EOF

update_kustomization ${BASE_DIR}/sources

git add -A
git commit -am "Added tigase source"

fi
