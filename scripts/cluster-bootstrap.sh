#!/bin/bash
#
# Script is the main entry point to setup entire k8s cluster.
# It first initializes k8s cluster with fluxcd, setups repository
# and then adds all listed services one by one.
# Execution of the entire script may take long time because the script
# waits until flux system fully reconcilled after each service is added
#

source `dirname "$0"`/scripts-env-init.sh

### Versions
# helm search repo ....

${SCRIPTS}/flux-bootstrap.sh || {
  echo "Unsuccessfull flux bootstrap, fix the problem and rerun"
  echo " \$ ${SCRIPTS}/flux-bootstrap.sh"
  exit 1
}

wait_for_ready

echo "DONE"

exit 1;

#BASE_TOOLS="common-sources ${SS_NAME} ${DA_NAME} ${IN_NAME} ${CM_NAME} ${LH_NAME} ${PM_NAME} ${LO_NAME} ${VE_NAME}"
BASE_TOOLS="common-sources ${SS_NAME} ${DA_NAME} ${IN_NAME} ${CM_NAME} ${LH_NAME} ${PM_NAME} ${LO_NAME}"

echo -e "\n\n   Deploying base tools ${BASE_TOOLS}"

for NAME in ${BASE_TOOLS} ; do
  ${SCRIPTS}/cluster-${NAME}.sh -q || {
    echo "Unsuccessful deployment for ${NAME}, correct the problem and rerun the script:"
    echo " \$ ${SCRIPTS}/cluster-${NAME}.sh"
    exit 1
  }
  wait_for_ready
done

