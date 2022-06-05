#!/bin/bash
#
# Script should be called from within a cluster-service.sh script 
# at the begining to execute certain actions depending on command
# line parameters
# 
# Currently implemented actions:
# --update - updates current service installation with changed
#            configuration and/or manifest files. Backups
#            should be made prior to avoid potential data loss
# --remove - completely uninstalls and removes the service
#            which, most likely means all service data erased
# --reset -  this property runs the '--remove' and then allows
#            the script to reinstall service from scratch
#

[ -z "$1" ] || {

  if [ -z "${CL_SERV_TYPE}" ] || [ -z "${CL_SERV_TNS}" ] || [ -z "${CL_SERV_NAME}" ] ; then
    echo "Script not prepared yet for preprocessing, $1 failed."
    exit 1
  fi

  CL_SERV_ACTION=${1:2}
  CL_DIR=`prepdir_ns ${INFRA}/${CL_SERV_TYPE} ${CL_SERV_TNS} ${FLUX_NS}`

  cl_serv_update() {
    echo "    ${INFO}Preparing to ${CL_SERV_ACTION}: ${CL_SERV_NAME}"
    echo "    Removing: ${CL_DIR}${NORMAL}"
    rm -rf ${CL_DIR}
  }

  cl_serv_remove() {
    cl_serv_update
    update_kustomization  ${CL_DIR%${CL_SERV_TNS}}
    echo "    ${INFO}Removing: ${BASE_DIR}/sources/${CL_SERV_NAME}.yaml${NORMAL}"
    rm -f ${BASE_DIR}/sources/${CL_SERV_NAME}.yaml
    update_kustomization ${BASE_DIR}/sources
    update_repo "Removing ${CL_SERV_NAME}"
    [ "$1" == "--no-quit" ] || exit 0
  }

  cl_serv_reset() {
    cl_serv_remove --no-quit
    wait_for_ready 10 ${CL_SERV_NAME}
  }

  case ${CL_SERV_ACTION} in

    update)
      cl_serv_update
      ;;

    remove)
      cl_serv_remove
      ;;

    reset)
      cl_serv_reset
      ;;

  esac

}

