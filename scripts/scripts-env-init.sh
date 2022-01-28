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

[ ! -d "$CONFIG" ] && mkdir $CONFIG

SCRIPT_DIR=`realpath "$0"`
export SCRIPTS=`dirname "$SCRIPT_DIR"`
#`pwd`/`dirname "$0"`

echo "Using config from $CONFIG and scripts from $SCRIPTS";

source "${CONFIG}/envs/cluster.env" || { echo "No cluster.env file"; exit 1; }
source "${CONFIG}/envs/versions.env" || { echo "No versions.env file"; exit 1; }
source "${SCRIPTS}/cluster-tools.sh" || exit 1
