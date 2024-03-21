#!/usr/bin/env bash
# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

# Script to be executed by ForgeRock Access Management (AM) Kubernetes
# container on startup.

# Legal Notice:
# Installation and use of this script is subject to a license agreement
# with Midships Limited (a company registered in England, under company
# registration number: 11324587). This script cannot be modified or
# shared with another organisation unless approved in writing by Midships
# Limited. You as a user of this script must review, accept and comply
# with the license terms of each downloaded/installed package that is
# referenced by this script. By proceeding with the installation, you are
# accepting the license terms of each package, and acknowledging that your
# use of each package will be subject to its respective license terms.
# For more information visit www.midships.io

# NOTE:
# Don't check this file into source control with any sensitive hard
# coded values.
# ========================================================================

echo "================================================================"
echo "||                ForgeRock Access Manager (AM)               ||"
echo "================================================================"
echo "->                   AM_HOME: ${AM_HOME}"
echo "->                VERSION_AM: ${VERSION_AM}"
echo "->          VERSION (Amster): ${VERSION}"
echo "->       AM_PATH_CONFIG_BASE: ${AM_PATH_CONFIG_BASE}"
echo "->            AM_PATH_CONFIG: ${AM_PATH_CONFIG}"
echo "->         AM_PATH_KEYSTORES: ${AM_PATH_KEYSTORES} "
echo "->    AM_PATH_SECRETS_AMSTER: ${AM_PATH_SECRETS_AMSTER}"
echo "->   AM_PATH_SECRETS_DEFAULT: ${AM_PATH_SECRETS_DEFAULT}"
echo "-> AM_PATH_SECRETS_ENCRYPTED: ${AM_PATH_SECRETS_ENCRYPTED}"
echo "-> AM_PATH_SECRETS_IN_CLIENT: ${AM_PATH_SECRETS_IN_CLIENT}"
echo "->          AM_PATH_SECURITY: ${AM_PATH_SECURITY}"
echo "->             AM_PATH_TOOLS: ${AM_PATH_TOOLS}"
echo "->            AM_SERVER_FQDN: ${AM_SERVER_FQDN}"
echo "->            AM_SERVER_PORT: ${AM_SERVER_PORT}"
echo "->        AM_SERVER_PROTOCOL: ${AM_SERVER_PROTOCOL}"
echo "->                    AM_URI: ${AM_URI}"
echo "->               AMSTER_HOME: ${AMSTER_HOME}"
echo "->             CATALINA_HOME: ${CATALINA_HOME}"
echo "->                  ENV_TYPE: ${ENV_TYPE}"
echo "->                  HOSTNAME: ${HOSTNAME}"
echo "->              JAVA_CACERTS: ${JAVA_CACERTS}"
echo "->                 JAVA_HOME: ${JAVA_HOME}"
echo "->         LOAD_APP_POLICIES: ${LOAD_APP_POLICIES}"
echo "->          LOAD_LOGBACK_XML: ${LOAD_LOGBACK_XML}"
echo "->             POD_NAMESPACE: ${POD_NAMESPACE}"
echo "->              SECRETS_MODE: ${SECRETS_MODE}"
if [ "${SECRETS_MODE,,}" != "volume" ]; then
echo "->   SECRETS_MANAGER_BASE_URL: ${SECRETS_MANAGER_BASE_URL}"
echo "->    SECRETS_MANAGER_PATH_AM: ${SECRETS_MANAGER_PATH_AM}"
echo "->   SECRETS_MANAGER_PATH_APS: ${SECRETS_MANAGER_PATH_APS}"
echo "->    SECRETS_MANAGER_PATH_TS: ${SECRETS_MANAGER_PATH_TS}"
echo "->    SECRETS_MANAGER_PATH_US: ${SECRETS_MANAGER_PATH_US}"
echo "->      SECRETS_MANAGER_TOKEN: ${SECRETS_MANAGER_TOKEN}"
fi
echo "================================================================"
echo ""

source "${AM_HOME}/scripts/forgerock-am-shared-functions.sh"

# Local Variables
# ---------------
errorFound=false
path_tmpFolder="/tmp/am"
path_AmLogbackXml="${CATALINA_HOME}/webapps/${AM_URI:=am}/WEB-INF/classes/logback.xml"
path_amCookieFile="${path_tmpFolder}/cookie.txt"

serverUrl=""
amPort="000"
path_tmp01=

echo "Checking Base directories"
echo "-------------------------"
mkdir -p "${path_tmpFolder}"
if [ ! -d "${AM_PATH_CONFIG}" ]; then
  echo "-- ERROR: Main config directory '${AM_PATH_CONFIG}' was NOT found. Exiting ..."
  exit 1
fi
if [ ! -d "${AM_PATH_CONFIG_BASE}" ]; then
  echo "-- ERROR: Base config directory '${AM_PATH_CONFIG_BASE}' was NOT found. Exiting ..."
  exit 1
fi
echo "-- Done"
echo ""

echo "Checking Environment variables"
echo "------------------------------"
if [ -z "${ENV_TYPE}" ]; then
  echo "-- WARN: ENV_TYPE is empty."
  echo "-- Please set environment variable to 'dev', 'sit', 'uat', 'nft', etc."
  echo "   Defaultinng to 'dev'"
  export ENV_TYPE="dev"
fi
if [ "${ENV_TYPE,,}" == "dev" ] || [[ "${ENV_TYPE,,}" == *"dev"* ]]; then
  path_tmp01="${AM_PATH_CONFIG}/amster/amster_rsa"
  echo "-- Removing existing Amster RSA file"
  rm -rf "${path_tmp01}"
  echo "-- Restoring configuration from '${AM_PATH_CONFIG_BASE}'"
  cp -R ${AM_PATH_CONFIG_BASE}/. ${AM_PATH_CONFIG}  
  if [ -f "${path_tmp01}" ]; then
    echo "-- Setting shared Amster RSA file permission"
    chmod 400 ${path_tmp01}
  else
    echo "-- ERROR: Shared Amster RSA file '${path_tmp01}' NOT found"
    errorFound="true"
  fi
else
  rm -rf "${AM_PATH_CONFIG}/amster/amster_rsa"
  rm -rf "${AM_PATH_CONFIG_BASE}/amster/amster_rsa"
  echo "-- Removed backed up shared Amster RSA as not required"
fi
if [ -z "${AM_REALMS}" ]; then
  echo "-- WARN: AM_REALMS is empty. Used for managing policies and applications."
  echo "   If empty, Applications and Policies activities will be skipped."
  echo "   Space separated list of your Realms. E.g. /realm01 /realm02 /realm03"
fi
echo "-- Done"
echo ""

setEnvVarsWithSecerts "${SECRETS_MODE}" "${AM_PATH_SECRETS_IN_CLIENT}" "${SECRETS_MANAGER_TOKEN}" # Must be ran before any Environment variable usage
makeServerFqdnSameAsSite "${AM_SERVER_PROTOCOL}" "${AM_SERVER_FQDN}" "${AM_SERVER_PORT}" "${AM_URI}"
createAMkeystoreAndSecrets "${AM_KEYSTORE_DEFAULT_PASSWORD}" "${AM_KEYSTORE_DEFAULT_ENTRY_PASSWORD}"

echo "Generating and updating required secrets and configurations"
echo "----------------------------------------------------------"
AM_PASSWORDS_DSAMEUSER_CLEAR="$(generateRandomString)"
export AM_PASSWORDS_DSAMEUSER_HASHED_ENCRYPTED="$(echo $AM_PASSWORDS_DSAMEUSER_CLEAR | am-crypto hash encrypt des)"
export AM_PASSWORDS_DSAMEUSER_ENCRYPTED="$(echo $AM_PASSWORDS_DSAMEUSER_CLEAR | am-crypto encrypt des)"
unset AM_PASSWORDS_DSAMEUSER_CLEAR
echo "-- Generated DSAMEUSER details"

AM_PASSWORDS_ANONYMOUS_CLEAR=${AM_PASSWORDS_ANONYMOUS_CLEAR:-$(generateRandomString)}
AM_PASSWORDS_ANONYMOUS_HASHED=${AM_PASSWORDS_ANONYMOUS_HASHED:-$(echo $AM_PASSWORDS_ANONYMOUS_CLEAR | am-crypto hash)}
export AM_PASSWORDS_ANONYMOUS_HASHED_ENCRYPTED=$(echo $AM_PASSWORDS_ANONYMOUS_HASHED | am-crypto encrypt des)
unset AM_PASSWORDS_ANONYMOUS_CLEAR
echo "-- Generated AM ANONYMOUS details"

AM_PASSWORDS_AMADMIN_HASHED=${AM_PASSWORDS_AMADMIN_HASHED:-$(echo $AM_PASSWORDS_AMADMIN_CLEAR | am-crypto hash)}
export AM_PASSWORDS_AMADMIN_HASHED_ENCRYPTED=$(echo $AM_PASSWORDS_AMADMIN_HASHED | am-crypto encrypt des)
echo "-- Hashed and encrypted AMADMIN details"

export AM_MONITORING_PROMETHEUS_PASSWORD_ENCRYPTED=$( echo -n "${AM_PROMETHEUS_PASSWORD:-prometheus}" | am-crypto encrypt des )
echo "-- Prometheus credentials updated"

export AM_KEYSTORE_DEFAULT_PASSWORD=$(cat ${AM_PATH_SECRETS_DEFAULT}/.storepass)
export AM_KEYSTORE_DEFAULT_ENTRY_PASSWORD=$(cat ${AM_PATH_SECRETS_DEFAULT}/.keypass)
echo "-- Retreived generated Keyhstore credentials"

echo "-- AM_STORES_SSL_ENABLED set to '${AM_STORES_SSL_ENABLED}'"
if [ "$AM_STORES_SSL_ENABLED" == "true" ]; then
  export AM_STORES_USER_CONNECTION_MODE="${AM_STORES_USER_CONNECTION_MODE:-"LDAPS"}"
  export AM_AUTHENTICATION_MODULES_LDAP_CONNECTION_MODE="${AM_AUTHENTICATION_MODULES_LDAP_CONNECTION_MODE:-"LDAPS"}"
  export AM_STORES_CTS_SSL_ENABLED="${AM_STORES_CTS_SSL_ENABLED:-"$AM_STORES_SSL_ENABLED"}"
  export AM_STORES_APPLICATION_SSL_ENABLED="${AM_STORES_APPLICATION_SSL_ENABLED:-"$AM_STORES_SSL_ENABLED"}"
  export AM_STORES_POLICY_SSL_ENABLED="${AM_STORES_POLICY_SSL_ENABLED:-"$AM_STORES_APPLICATION_SSL_ENABLED"}"
  export AM_STORES_UMA_SSL_ENABLED="${AM_STORES_UMA_SSL_ENABLED:-"$AM_STORES_APPLICATION_SSL_ENABLED"}"
  echo "-- Enabled SSL for all stores"
else
  export AM_STORES_USER_CONNECTION_MODE="${AM_STORES_USER_CONNECTION_MODE:-"LDAP"}"
  export AM_AUTHENTICATION_MODULES_LDAP_CONNECTION_MODE="${AM_AUTHENTICATION_MODULES_LDAP_CONNECTION_MODE:-"LDAP"}"
  export AM_STORES_CTS_SSL_ENABLED="${AM_STORES_CTS_SSL_ENABLED:-"false"}"
  export AM_STORES_APPLICATION_SSL_ENABLED="${AM_STORES_APPLICATION_SSL_ENABLED:-"false"}"
  export AM_STORES_POLICY_SSL_ENABLED="${AM_STORES_POLICY_SSL_ENABLED:-"false"}"
  export AM_STORES_UMA_SSL_ENABLED="${AM_STORES_UMA_SSL_ENABLED:-"false"}"
  echo "-- Disbaled SSL for all stores"
fi

export AM_AUTHENTICATION_MODULES_LDAP_USERNAME="${AM_AUTHENTICATION_MODULES_LDAP_USERNAME:-"${AM_STORES_USER_USERNAME}"}"
export AM_AUTHENTICATION_MODULES_LDAP_PASSWORD="${AM_AUTHENTICATION_MODULES_LDAP_PASSWORD:-"${AM_STORES_USER_PASSWORD}"}"
export AM_AUTHENTICATION_MODULES_LDAP_SERVERS="${AM_AUTHENTICATION_MODULES_LDAP_SERVERS:-"${AM_STORES_USER_SERVERS}"}"
echo "-- Updated AUTHENTICATION_MODULES_LDAP details"

# Shared Secret, Encryption and Signing keys. MUST be the same on each AM instance"
[ -z "${AM_AUTHENTICATION_SHARED_SECRET}" ] && echo "-- ERROR: AM_AUTHENTICATION_SHARED_SECRET is either empty or not set. Should be a base64 encoded string." && errorFound="true"
[ -z "${AM_SESSION_STATELESS_SIGNING_KEY}" ] && echo "-- ERROR: AM_SESSION_STATELESS_SIGNING_KEY is either empty or not set. Should be a base64 encoded string." && errorFound="true"
[ -z "${AM_SESSION_STATELESS_ENCRYPTION_KEY}" ] && echo "-- ERROR: AM_SESSION_STATELESS_ENCRYPTION_KEY is either empty or not set. Should be a base64 encoded string." && errorFound="true"
[ -z "${AM_SESSION_STATELESS_ENCRYPTION_KEY}" ] && echo "-- ERROR: AM_SESSION_STATELESS_ENCRYPTION_KEY is either empty or not set." && errorFound="true"
[ -z "${AM_SELFSERVICE_LEGACY_CONFIRMATION_EMAIL_LINK_SIGNING_KEY}" ] && echo "-- ERROR: AM_SELFSERVICE_LEGACY_CONFIRMATION_EMAIL_LINK_SIGNING_KEY is either empty or not set." && errorFound="true"
echo "-- Done"
echo ""

# Check AM configuraiton for missing placeholder environment variables
listRequiredAmVars "${AM_PATH_CONFIG}/services"

if [ "${errorFound}" == "false" ]; then
  echo "-> Setting Server URL and Loadbalancer URL"
  [ -z "${AM_SERVER_PROTOCOL}" ] && AM_SERVER_PROTOCOL="https"
  [ -z "${AM_SERVER_PORT}" ] && AM_SERVER_PORT="8443"
  [ -z "${AM_URI}" ] && AM_URI="am"
  serverUrl="${AM_SERVER_PROTOCOL}://${AM_SERVER_FQDN}:${AM_SERVER_PORT}/${AM_URI}"
  echo "   serverUrl: '${serverUrl}'"
  echo "-- Done"
  echo ""

  echo "Setting up Trust Store annd Key Store"
  echo "-------------------------------------"
  echo "> Trust Store (JAVA_CACERTS): '${JAVA_CACERTS}'"
  echo "> Key Store (Tomcat) to create: '${CATALINA_JKS}'"
  echo ""
  changeTrustStorePassword "${JAVA_CACERTS}" "changeit" "${AM_PASSWORDS_TRUSTSTORE}"
  addDataStoreCertsToTrustKeyStore "${CATALINA_JKS}" "${JAVA_CACERTS}" "${AM_KEYSTORE_DEFAULT_PASSWORD}" "${AM_PASSWORDS_TRUSTSTORE}"

  path_tomcatServerXml="${CATALINA_HOME}/conf/server.xml"
  path_tmp01="${AM_PATH_CONFIG}/server.xml"
  if [ -f "${path_tomcatServerXml}" ]; then
    echo "-> Updating Tomcat Keystore in '${path_tomcatServerXml}'"
    echo "-- Backing up xml..."
    cp -p "${path_tomcatServerXml}" "${path_tomcatServerXml}.bak"
    if [ -f "${path_tmp01}" ]; then
      echo "-- Copying Tomcat '${path_tmp01}' template to ${CATALINA_HOME}/conf"
      cp "${path_tmp01}" "${path_tomcatServerXml}"
      substituteEnvVars "${path_tomcatServerXml}"
    else
      echo "-- ERROR: '${path_tmp01}' NOT found."
      errorFound="true"
    fi
  else
      echo "-- ERROR: '${path_tmp01}' NOT found."
      errorFound="true"
  fi
  echo "-- Done"
  echo ""

  if [ "${errorFound}" == "false" ]; then
    echo "Preparing to startup Acess Manager"
    echo "----------------------------------"
    echo ""

    echo "> JAVA_OPTS:"
    echo "  See 'https://backstage.forgerock.com/docs/am/7/maintenance-guide/tuning-jvm-for-openam.html'"
    JAVA_OPTS="${JAVA_OPTS} -XX:+UseContainerSupport -Dfile.encoding=UTF-8 -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=256m -Xlog:gc=debug:file=/tmp/gc.log:time,uptime,pid,level,tags:filecount=5,filesize=100m"
    echo "  ${JAVA_OPTS}"
    echo ""
    
    echo "-> Adding JAVA_OPTS to '${CATALINA_HOME}/bin/setenv.sh'"
    echo  "export JAVA_OPTS=\"${JAVA_OPTS}\"" > ${CATALINA_HOME}/bin/setenv.sh
    echo "-- Done"  
    echo ""

    echo "-> Java Experimental Contaniner Settings: Limit Heap size to container"
    java -XX:+UseContainerSupport -XshowSettings:vm -version 
    echo ""

    echo "[ Checking that the Forgerock User, Token and AppPolicy Stores are all up and running ]"
    echo ""
    getSvcUrlFromFqdnPortString svcUrlAPS "${AM_STORES_APPLICATION_SERVERS}" "true"
    getSvcUrlFromFqdnPortString svcUrlTS "${AM_STORES_CTS_SERVERS}" "true"
    getSvcUrlFromFqdnPortString svcUrlUS "${AM_STORES_USER_SERVERS}" "true"
    echo ""
    checkServerIsAlive --svc "${svcUrlUS}" --type "ds" --channel "https" --port "${HTTPS_PORT_US}"
    checkServerIsAlive --svc "${svcUrlTS}" --type "ds" --channel "https" --port "${HTTPS_PORT_TS}"
    checkServerIsAlive --svc "${svcUrlAPS}" --type "ds" --channel "https" --port "${HTTPS_PORT_APS}"
    
    if [ "${LOAD_LOGBACK_XML,,}" == "true" ]; then
      path_tmp01="${AM_PATH_CONFIG}/logback.xml"
      if [ -f "${path_tmp01}" ]; then
        echo "-> Updating logback.xml"
        export CATALINA_OUT="/dev/stdout"
        echo "-- CATALINA_OUT updated to '${CATALINA_OUT}'"
        cp -Rp "${path_tmp01}" "${path_AmLogbackXml}"
        echo "-- Copied file '${path_tmp01}' to '${path_AmLogbackXml}'"
        echo "-- Done"
        echo ""
      else
        echo "-- ERROR: '${path_tmp01}' not found"
        errorFound="true"
      fi
    fi
  fi  
fi

if [ "${errorFound}" == "false" ]; then
  # Run in background while AM is strating up
  { 
    verifyAmLogin loginSucessful "${serverUrl}" "${path_amCookieFile}" "amadmin" "${AM_PASSWORDS_AMADMIN_CLEAR}";
    if [ "${loginSucessful}" == "true" ]; then
      manageAppsAndPolicies "${podIndx}" "${LOAD_APP_POLICIES}" "${serverUrl}" "${svcUrlAPS}" "https" "${HTTPS_PORT_APS}" "${AM_REALMS}";
      addSharedFile "/opt/am/am_setup_done" "access-manager-setup-done"; # Notify Startup probe
      cleanUpDeployFiles;
    else
      echo "-- ERROR: Skipping Loading Apps and Policies due to previous errors."
    fi
  } &
  applyBespokeSettings
  manageTomcat "start"
else
  echo "-- ERROR: See above for more details. Exiting ..."
  exit 1
fi
