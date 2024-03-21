#!/bin/bash
# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

# Script to be executed by ForgeRock Identity Manager (IDM) Kubernetes
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
echo "||              ForgeRock Identity Manager (IDM)              ||"
echo "================================================================"
echo "->                     ENV_TYPE: ${ENV_TYPE}"
echo "->                      VERSION: ${VERSION}"
echo "->                     HOSTNAME: ${HOSTNAME}"
echo "->                     IDM_HOME: ${IDM_HOME}"
echo "->                     PROJECTS: ${PROJECTS}"
echo "->                   CERT_ALIAS: ${CERT_ALIAS}"
echo "->                   CONFIGMAPS: ${CONFIGMAPS}"
echo "->                  CONFIG_BASE: ${CONFIG_BASE}"
echo "->              DS_REPO_BIND_DN: ${DS_REPO_BIND_DN}"
echo "->         DS_REPO_FQDN_PRIMARY: ${DS_REPO_FQDN_PRIMARY}"
echo "->       DS_REPO_FQDN_SECONDARY: ${DS_REPO_FQDN_SECONDARY}"
echo "->    DS_REPO_PORT_HTTP_PRIMARY: ${DS_REPO_PORT_HTTP_PRIMARY}"
echo "->  DS_REPO_PORT_HTTP_SECONDARY: ${DS_REPO_PORT_HTTP_SECONDARY}"
echo "->   DS_REPO_PORT_HTTPS_PRIMARY: ${DS_REPO_PORT_HTTPS_PRIMARY}"
echo "-> DS_REPO_PORT_HTTPS_SECONDARY: ${DS_REPO_PORT_HTTPS_SECONDARY}"
echo "->    DS_REPO_PORT_LDAP_PRIMARY: ${DS_REPO_PORT_LDAP_PRIMARY}"
echo "->  DS_REPO_PORT_LDAP_SECONDARY: ${DS_REPO_PORT_LDAP_SECONDARY}"
echo "->   DS_REPO_PORT_LDAPS_PRIMARY: ${DS_REPO_PORT_LDAPS_PRIMARY}"
echo "-> DS_REPO_PORT_LDAPS_SECONDARY: ${DS_REPO_PORT_LDAPS_SECONDARY}"
echo "->        DS_REPO_REPO_SECURITY: ${DS_REPO_REPO_SECURITY}"
echo "->                    PORT_HTTP: ${PORT_HTTP}"
echo "->                   PORT_HTTPS: ${PORT_HTTPS}"
echo "->             PORT_MUTUAL_AUTH: ${PORT_MUTUAL_AUTH}"
echo "->                      SECRETS: ${SECRETS}"
echo "->             UNAME_PROMETHEUS: ${UNAME_PROMETHEUS}"
echo "->                    NAMESPACE: ${NAMESPACE}"
echo "->                 SECRETS_MODE: ${SECRETS_MODE}"
if [ "${SECRETS_MODE,,}" != "volume" ]; then
echo "->      SECRETS_MANAGER_BASE_URL: ${SECRETS_MANAGER_BASE_URL}"
echo "->      SECRETS_MANAGER_PATH_IDM: ${SECRETS_MANAGER_PATH_IDM}"
echo "->       SECRETS_MANAGER_PATH_US: ${SECRETS_MANAGER_PATH_US}"
echo "->         SECRETS_MANAGER_TOKEN: ${SECRETS_MANAGER_TOKEN}" 
fi
echo "----------------------------------------------------------------"
echo ""
# Local Variables
# ---------------
path_tmpFolder="/tmp/idm"

source "${IDM_HOME}/scripts/forgerock-idm-shared-functions.sh"

echo "============================="
echo "Setting up a NEW IDM instance"
echo "============================="
echo ""

echo "Setting up pre-requsite(s)"
echo "--------------------------"
echo "-> Creating directories"
mkdir -p "${path_tmpFolder}" "${PROJECTS}"
echo "-- Done"
echo ""
setEnvVarsWithSecerts "${SECRETS_MODE}" "${SECRETS}" "${SECRETS_MANAGER_TOKEN}" # Must be ran before any Environment variable usage

[ ! -d "${CONFIG_BASE}" ] && echo "-- ERROR: IDM base config directory '${CONFIG_BASE}' NOT found." && exit 1

showEmptyEnvVars errorFound

if [ "${errorFound}" != "true" ]; then
  echo "Importing configuration file(s)"
  echo "-------------------------------"
  path_from="${CONFIG_BASE}/conf"
  path_to="${IDM_HOME}/conf"
  echo "From: ${path_from}"
  echo "  To: ${path_to}"
  [ ! -d "${path_from}" ] && echo "-- WARN: Directory '${path_from}' NOT found. Skipping import."
  echo ""
  echo -e "[*.json]\n"
  for currFile in ${path_from}/*.json; do
    filePath="${path_to}/$(basename ${currFile})"
    echo "-> Processing '${currFile}'"
    cp "${currFile}" "${filePath}"
    echo "-- File copied to '${filePath}'"
    substituteEnvVars "${filePath}"
  done
  echo -e "[*.properties]\n"    
  for currFile in ${path_from}/*.properties; do
    filePath="${path_to}/$(basename ${currFile})"
    echo "-> Processing '${currFile}'"
    cp "${currFile}" "${filePath}"
    echo "-- File copied to '${filePath}'"
    substituteEnvVars "${filePath}"
  done
  echo -e "[*.xml]\n"
  echo -e "[*.properties]\n"    
  for currFile in ${path_from}/*.xml; do
    filePath="${path_to}/$(basename ${currFile})"
    echo "-> Processing '${currFile}'"
    cp "${currFile}" "${filePath}"
    echo "-- File copied to '${filePath}'"
    substituteEnvVars "${filePath}"
  done

  echo -e "[resolver files]\n"
  path_from="${CONFIG_BASE}/resolver"
  path_to="${IDM_HOME}/resolver"
  [ ! -d "${path_from}" ] && echo "-- WARN: Directory '${path_from}' NOT found. Skipping import."
  for currFile in ${path_from}/*.properties; do
    filePath="${path_to}/$(basename ${currFile})"
    echo "-> Processing '${currFile}'"
    cp "${currFile}" "${filePath}"
    echo "-- File copied to '${filePath}'"
    substituteEnvVars "${filePath}"
  done

  case ${PROFILE} in
    "ds")
      if [ -z "${DS_REPO_BIND_DN}" ] || [ -z "${DS_REPO_REPO_SECURITY}" ] || \
          [ -z "${DS_REPO_PORT_LDAPS_PRIMARY}" ] || [ -z "${DS_REPO_PORT_LDAPS_SECONDARY}" ] || \
          [ -z "${DS_REPO_FQDN_PRIMARY}" ] || [ -z "${DS_REPO_FQDN_SECONDARY}" ] || \
          [ -z "${DS_REPO_PORT_HTTP_PRIMARY}" ] || [ -z "${DS_REPO_PORT_HTTPS_PRIMARY}" ] || \
          [ -z "${DS_REPO_PORT_HTTP_SECONDARY}" ] || [ -z "${DS_REPO_PORT_HTTPS_SECONDARY}" ]; then
        echo "-- ERROR: Either one or more of the below required paramters are empty:"
        echo "          > DS_REPO_BIND_DN: ${DS_REPO_BIND_DN}"
        echo "          > DS_REPO_REPO_SECURITY: ${DS_REPO_REPO_SECURITY}"
        echo "          > DS_REPO_PORT_LDAPS_PRIMARY: ${DS_REPO_PORT_LDAPS_PRIMARY}"
        echo "          > DS_REPO_PORT_LDAPS_SECONDARY: ${DS_REPO_PORT_LDAPS_SECONDARY}"
        echo "          > DS_REPO_FQDN_PRIMARY: ${DS_REPO_FQDN_PRIMARY}"
        echo "          > DS_REPO_FQDN_SECONDARY: ${DS_REPO_FQDN_SECONDARY}"
        echo "          > DS_REPO_PORT_HTTP_PRIMARY: ${DS_REPO_PORT_HTTP_PRIMARY}"
        echo "          > DS_REPO_PORT_HTTPS_PRIMARY: ${DS_REPO_PORT_HTTPS_PRIMARY}"
        echo "          > DS_REPO_PORT_HTTP_SECONDARY: ${DS_REPO_PORT_HTTP_SECONDARY}"
        echo "          > DS_REPO_PORT_HTTPS_SECONDARY: ${DS_REPO_PORT_HTTPS_SECONDARY}"
        echo "          Please correct and retry. Exiting ..."
        exit 1
      fi
      ;;
    "mysql")
      echo -n "-- ERROR: PROFILE set to 'mysql'. This is NOT possible at present."
      exit 1
      ;;
    "oracle")
      echo -n "-- ERROR: PROFILE set to 'oracle'. This is NOT possible at present."
      exit 1
      ;;
    "embeded")
      echo "-- WARN: IDM will be started with an Embedded Directory Services (DS) as repository. Do NOT use for production."
      echo ""
      ;;
    *)
      errorFound="true"
      echo "-- ERROR: Invalid PROFILE provided. Exiting ..."
      ;;
  esac

  if [ "${errorFound}" == "false" ]; then
    updateTruststore "${TRUSTSTORE}" "changeit" "${SECRET_PASSWORD_TRUSTSTORE}"
    applyIdmDefaultHardening "${KEYSTORE}" "${SECRET_PASSWORD_KEYSTORE}"
    importCertIntoTrustStore "user-store" "${SECRET_CERTIFICATE_US}" "${TRUSTSTORE}" "${SECRET_PASSWORD_TRUSTSTORE}"
    checkServerIsAlive --svc "${DS_REPO_FQDN_PRIMARY}" --type "ds" --channel "https" --port "${DS_REPO_PORT_HTTPS_PRIMARY}" --iterations "60"

    echo "-> Starting IDM ..."
    "${IDM_HOME}/startup.sh"
  fi
fi

if [ "${errorFound}" != "true" ]; then
  echo "-- ERROR: See above for more details. Exiting ..."
  exit 1
fi