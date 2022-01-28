#!/bin/bash
#
# Script is the main entry point to setup entire k8s cluster.
# It first initializes k8s cluster with fluxcd, setups repository
# and then adds all listed services one by one.
# Execution of the entire script may take long time because the script
# waits until flux system fully reconcilled after each service is added
#

if [ -z "$TIG_CLUSTER_HOME" ]; then
	export CONFIG="$HOME/.tigase-flux"
else 
	export CONFIG="$TIG_CLUSTER_HOME"
fi

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

if [ "$COLORED_OUTPUT" = true ]; then
	export BOLD="$(tput bold)"
	export RED="$(tput setaf 1)"
	export GREEN="$(tput setaf 2)"
	export NORMAL="$(tput sgr0)"
	export CYAN="$(tput setaf 6)"
else
	export BOLD=""
	export RED=""
	export GREEN=""
	export NORMAL=""
	export CYAN=""
fi
export ERROR="$BOLD$RED"

source "${CONFIG}/envs/versions.env" || { echo "${ERROR}No versions.env file${NORMAL}"; exit 1; }
source "${SCRIPTS}/cluster-tools.sh" || exit 1

