#!/bin/bash
#
# Script is the main entry point to setup entire k8s cluster.
# It first initializes k8s cluster with fluxcd, setups repository
# and then adds all listed services one by one.
# Execution of the entire script may take long time because the script
# waits until flux system fully reconcilled after each service is added
#

[ -z ${K8S_CONTEXT} ] && {
  echo "K8S_CONTEXT not set."
  echo "You have to set K8S_CONTEXT environment to your k8s context:"
  echo "kubectl config get-contexts"
  echo "Then set your context name as the variable value:"
  echo "export K8S_CONTEXT=context-name"
  exit 1
}

if [ -z "$TIG_CLUSTER_HOME" ]; then
	export CONFIG="$HOME/.tigase-flux"
else 
	export CONFIG="$TIG_CLUSTER_HOME"
fi

export CONFIG="${CONFIG}/${K8S_CONTEXT}"

if [ ! -d "$CONFIG" ]; then
	echo "Config directory $CONFIG does not exist!";
	exit 1;
fi

export TMP_DIR="$CONFIG/tmp"

[ ! -d "$TMP_DIR" ] && mkdir $TMP_DIR

SCRIPT_DIR=`realpath "$0"`
export SCRIPTS=`dirname "$SCRIPT_DIR"`

if [ ! -d "$CONFIG/envs" ]; then
	echo "Environment directory $CONFIG/envs does not exist!";
	exit 1;
fi

source "${CONFIG}/envs/cluster.env" || { echo "No cluster.env file"; exit 1; }

kubectl config use-context ${K8S_CONTEXT}

if [ "$COLORED_OUTPUT" = true ]; then
	export BOLD="$(tput bold)"
	export RED="$(tput setaf 1)"
	export GREEN="$(tput setaf 2)"
	export NORMAL="$(tput sgr0)"
	export CYAN="$(tput setaf 6)"
	export YELLOW="$(tput setaf 3)"
else
	export BOLD=""
	export RED=""
	export GREEN=""
	export NORMAL=""
	export CYAN=""
	export YELLOW=""
fi
export ERROR="$BOLD$RED"
export WARNING="$BOLD$YELLOW"
export INFO="$BOLD$GREEN"

# Make sure all required executables are installed
REQUIRED_CMDS="pwgen kubectl kubeseal flux kustomize git yq"

for CMD in $REQUIRED_CMDS; do
  if ! command -v "$CMD" &> /dev/null; then
      echo "${ERROR}$CMD could not be found!${NORMAL}"
      exit
  fi
done

source "${CONFIG}/envs/versions.env" || { echo "${ERROR}No versions.env file${NORMAL}"; exit 1; }
source "${SCRIPTS}/cluster-tools.sh" || exit 1

if [ -z "$SSL_ISSUER" ]; then
  export SSL_ISSUER="$SSL_STAG_ISSUER";
fi

[ "$1" != "--check" ] || echo "All seems to be OK and ready to go"
