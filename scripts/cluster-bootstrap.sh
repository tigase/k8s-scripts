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

echo "${BOLD}Bootstraping flux...${NORMAL}"
${SCRIPTS}/flux-bootstrap.sh || {
  echo "${ERROR}Unsuccessfull flux bootstrap, fix the problem and rerun${NORMAL}"
  echo " \$ ${SCRIPTS}/flux-bootstrap.sh"
  exit 1
}

wait_for_ready

#BASE_TOOLS="common-sources ${SS_NAME} ${DA_NAME} ${IN_NAME} ${CM_NAME} ${LH_NAME} ${PM_NAME} ${LO_NAME} ${VE_NAME}"
BASE_TOOLS="common-sources ${SS_NAME} ${DA_NAME} ${IN_NAME} ${CM_NAME} ${LH_NAME} ${PM_NAME} ${LO_NAME} ${ONEDEV_NAME}"

echo -e "\n\n   ${BOLD}Deploying base tools ${BASE_TOOLS}${NORMAL}"

for NAME in ${BASE_TOOLS} ; do
  ${SCRIPTS}/cluster-${NAME}.sh -q || {
    echo "${ERROR}Unsuccessful deployment for ${NAME}, correct the problem and rerun the script:${NORMAL}"
    echo " \$ ${SCRIPTS}/cluster-${NAME}.sh"
    exit 1
  }
  wait_for_ready
done

echo -e "\n\n   ${BOLD}${GREEN}Deployment finished successfully!${NORMAL}"

