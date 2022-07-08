#!/bin/bash

######
# If you forgot or lost login credentials for basic-auth for an HTTP(S) service
# this utility script can reinstall the secret with new credentials
#

source `dirname "$0"`/scripts-env-init.sh

[[ -z "$1" ]] && {
  echo "Provide a namespace as the first parameter"
  exit 1
}
ns=$1

u_name=""
u_pass=""

[[ "$1" == "-q" ]] || {
  echo -n "Provide ${ns} user name or ENTER to generate: "; read u_name
  echo -n "Provide ${ns} user password or ENTER to generate: "; read u_pass
}
[[ -z "${u_name}" ]] && u_name=`gen_token 8`
USER_NAME=${u_name}
[[ -z "${u_pass}" ]] && u_pass=`gen_token 24`
USER_PASS=${u_pass}

update_k8s_secrets "${ns}-user" ${USER_NAME}
update_k8s_secrets "${ns}-pass" ${USER_PASS}

AUTH_FILE="$TMP_DIR/auth"
rm -f $AUTH_FILE

echo "${USER_NAME}:$(openssl passwd -stdin -apr1 <<< ${USER_PASS})" >> $AUTH_FILE

cat $AUTH_FILE

if [ "$2" == "--reinstall" ]; then
  kubectl delete secret basic-auth -n ${ns}
fi

kubectl -n ${ns} create secret generic basic-auth --from-file=$AUTH_FILE

