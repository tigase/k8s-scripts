#!/bin/bash
#
# Script deploys Weblate on the k8s cluster.
#

source `dirname "$0"`/scripts-env-init.sh

INTERVAL="${DEF_INTERVAL}"
SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-${CLUSTER_NAME}.pem"

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "${ERROR}No cluster repo dir!${NORMAL}"; exit 1; }

TNS=${WEBLATE_TARGET_NAMESPACE}

if [ -z "${WEBLATE_SITE_TITLE}" ]; then
  echo -n "Provide Weblate site title: "; read o_key;
  [[ -z ${o_key} ]] || WEBLATE_SITE_TITLE=${o_key}
fi
if [ -z "${WEBLATE_SITE_DOMAIN}" ]; then
  echo -n "Provide Weblate site domain: "; read o_key;
  [[ -z ${o_key} ]] || WEBLATE_SITE_DOMAIN=${o_key}
fi
if [ -z "${WEBLATE_ADMIN_EMAIL}" ]; then
  echo -n "Provide Weblate admin email: "; read o_key;
  [[ -z ${o_key} ]] || WEBLATE_ADMIN_EMAIL=${o_key}
fi
if [ -z "${WEBLATE_EMAIL_HOST}" ]; then
  echo -n "Provide Weblate email host: "; read o_key;
  [[ -z ${o_key} ]] || WEBLATE_EMAIL_HOST=${o_key}
fi
if [ -z "${WEBLATE_EMAIL_SSL}" ]; then
  echo -n "Provide Weblate email SSL (true/false): "; read o_key;
  if [ "true" == "${o_key}" ]; then
    WEBLATE_EMAIL_SSL=true
  else
    WEBLATE_EMAIL_SSL=false
  fi
fi
if [ -z "${WEBLATE_EMAIL_USER}" ]; then
  echo -n "Provide Weblate email user: "; read o_key;
  [[ -z ${o_key} ]] || WEBLATE_EMAIL_USER=${o_key}
  if [ -z "${WEBLATE_EMAIL_PASSWORD}" ]; then
    echo -n "Provide Weblate email password: "; read p_key;
    [[ -z ${p_key} ]] || WEBLATE_EMAIL_PASSWORD=${p_key}
  fi
fi
if [ -z "${WEBLATE_EMAIL_ADDRESS}" ]; then
  echo -n "Provide Weblate email address: "; read o_key;
  [[ -z ${o_key} ]] || WEBLATE_EMAIL_ADDRESS=${o_key}
fi

if [ -z "${WEBLATE_SOCIAL_AUTH_GITHUB_KEY}" ]; then
  echo -n "Provide GitHub OAuth key: "; read o_key;
  [[ -z ${o_key} ]] || WEBLATE_SOCIAL_AUTH_GITHUB_KEY=${o_key}

  if [ ! -z "${WEBLATE_SOCIAL_AUTH_GITHUB_KEY}" ]; then
  	if [ -z "${WEBLATE_SOCIAL_AUTH_GITHUB_SECRET}" ]; then
	  echo -n "Provide GitHub OAuth secret: "; read s_key;
  	  [[ -z ${s_key} ]] || WEBLATE_SOCIAL_AUTH_GITHUB_SECRET=${s_key}
  	fi
  fi  
fi

if [ -z "${WEBLATE_SOCIAL_AUTH_GITHUB_ORG_KEY}" ]; then
  echo -n "Provide GitHubOrg OAuth key: "; read o_key;
  [[ -z ${o_key} ]] || WEBLATE_SOCIAL_AUTH_GITHUB_ORG_KEY=${o_key}

  if [ ! -z "${WEBLATE_SOCIAL_AUTH_GITHUB_ORG_KEY}" ]; then
  	if [ -z "${WEBLATE_SOCIAL_AUTH_GITHUB_ORG_SECRET}" ]; then
	  echo -n "Provide GitHubOrg OAuth secret: "; read s_key;
  	  [[ -z ${s_key} ]] || WEBLATE_SOCIAL_AUTH_GITHUB_ORG_SECRET=${s_key}
  	fi
  	if [ -z "${WEBLATE_SOCIAL_AUTH_GITHUB_ORG_NAME}" ]; then
	  echo -n "Provide GitHubOrg OAuth organization name: "; read n_key;
  	  [[ -z ${n_key} ]] || WEBLATE_SOCIAL_AUTH_GITHUB_ORG_NAME=${n_key}
  	fi
  fi  
fi

echo "      ${BOLD}Adding Weblate helm chart${NORMAL}"

${SCRIPTS}/flux-create-source.sh ${WEBLATE_S_NAME} ${WEBLATE_URL}

update_kustomization ${BASE_DIR}/sources

echo "      ${BOLD}Preparing Weblate deployment${NORMAL}"

NAME="${WEBLATE_NAME}"

${SCRIPTS}/flux-create-helmrel.sh app \
        "${WEBLATE_NAME}" \
        "${WEBLATE_VER}" \
        "${WEBLATE_RNAME}" \
        "${WEBLATE_TARGET_NAMESPACE}" \
        "${WEBLATE_NAMESPACE}" \
        "${WEBLATE_SOURCE}" \
        "${WEBLATE_VALUES}" --create-target-namespace || exit 1

VALUES=""
VALUES="$VALUES\n    adminEmail: \"${WEBLATE_ADMIN_EMAIL}\""
VALUES="$VALUES\n    siteTitle: \"${WEBLATE_SITE_TITLE}\""
VALUES="$VALUES\n    siteDomain: \"${WEBLATE_SITE_DOMAIN}\""
VALUES="$VALUES\n    emailHost: \"${WEBLATE_EMAIL_HOST}\""
VALUES="$VALUES\n    emailSSL: ${WEBLATE_EMAIL_SSL}"
VALUES="$VALUES\n    emailUser: \"${WEBLATE_EMAIL_USER}\""
VALUES="$VALUES\n    emailPassword: \"${WEBLATE_EMAIL_PASSWORD}\""
VALUES="$VALUES\n    serverEmail: \"${WEBLATE_EMAIL_ADDRESS}\""
VALUES="$VALUES\n    defaultFromEmail: \"${WEBLATE_EMAIL_ADDRESS}\""

VALUES="$VALUES\n    extraConfig:"
[ -z "$WEBLATE_SOCIAL_AUTH_GITHUB_KEY" ] \
	|| VALUES="$VALUES\n      WEBLATE_SOCIAL_AUTH_GITHUB_KEY=\"${WEBLATE_SOCIAL_AUTH_GITHUB_KEY}\""
[ -z "$WEBLATE_SOCIAL_AUTH_GITHUB_SECRET" ] \
    || VALUES="$VALUES\n      WEBLATE_SOCIAL_AUTH_GITHUB_SECRET=\"${WEBLATE_SOCIAL_AUTH_GITHUB_SECRET}\"" 
[ -z "$WEBLATE_SOCIAL_AUTH_GITHUB_ORG_KEY" ] \
	|| VALUES="$VALUES\n      WEBLATE_SOCIAL_AUTH_GITHUB_ORG_KEY=\"${WEBLATE_SOCIAL_AUTH_GITHUB_ORG_KEY}\""
[ -z "$WEBLATE_SOCIAL_AUTH_GITHUB_ORG_SECRET" ] \
    || VALUES="$VALUES\n      WEBLATE_SOCIAL_AUTH_GITHUB_ORG_SECRET=\"${WEBLATE_SOCIAL_AUTH_GITHUB_ORG_SECRET}\"" 
[ -z "$WEBLATE_SOCIAL_AUTH_GITHUB_ORG_NAME" ] \  
    || VALUES="$VALUES\n      WEBLATE_SOCIAL_AUTH_GITHUB_ORG_NAME=\"${WEBLATE_SOCIAL_AUTH_GITHUB_ORG_NAME}\"" 

VALUES="$VALUES\n    ingress:"
VALUES="$VALUES\n      enabled: true"
VALUES="$VALUES\n      annotations:"
VALUES="$VALUES\n        cert-manager.io/cluster-issuer: \"letsencrypt\""
VALUES="$VALUES\n      hosts:"
VALUES="$VALUES\n        - host: \"${WEBLATE_SITE_DOMAIN}\""
VALUES="$VALUES\n          paths:"
VALUES="$VALUES\n            - /"
VALUES="$VALUES\n      tls:"
VALUES="$VALUES\n        - secretName: \"${WEBLATE_NAME}-translate\""
VALUES="$VALUES\n          hosts:"
VALUES="$VALUES\n            - \"${WEBLATE_SITE_DOMAIN}\""

CL_DIR=`mkdir_ns ${APPS_DIR} ${TNS} ${FLUX_NS}`
NAME=${WEBLATE_NAME}

printf "\n$VALUES" >> "${CL_DIR}/${NAME}/${NAME}.yaml"

echo "      ${BOLD}Deploying changes${NORMAL}"

#update_repo ${NAME}

#wait_for_ready
