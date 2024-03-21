#!/bin/bash
# ==================================================================
# MIDSHIPS
# COPYRIGHT 2023

# Script to support the execution of the ForgeRock Identity Management
# (IDM) Kubernetes container on startup.

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
# ===================================================================
# Inherit Midhsips shared functions
source "${MIDSHIPS_SCRIPTS}/midshipscore.sh"

path_tmpFolder="/tmp/idm"
echo "-> Creating Temp Folder '${path_tmpFolder}'"
mkdir -p "${path_tmpFolder}"
echo "-- Done"
echo ""

# ------------------------------------------------------------------------------
# Re-creates the default required Keys that are deployed in a ForgeRock Identity
# Manager (IDM) Keystore
#
# NOTE: IDM must be restarted for these changes to take effect
#
# Parameters:
#  - ${1}: Path to IDM Keystore file
#  - ${2}: Keystore type. E.g. JCEKS, JKS, etc.
#  - ${3}: Keystore Password
# ------------------------------------------------------------------------------
function recreateIDMkeyStore() {
  local path_idmKeystore="${1}"
  local idmKeystoreType="${2}"
  local idmKeystorePwd="${3}"
  local path_idmKeystorePwd="${IDM_HOME}/resolver/keystore/keystore.properties"

  if [ -z "${path_idmKeystore}" ] || [ "${path_idmKeystore}" == "null" ] || \
     [ -z "${idmKeystorePwd}" ] || [ "${idmKeystorePwd}" == "null" ] || \
     [ -z "${idmKeystoreType}" ] || [ "${idmKeystoreType}" == "null" ]; then
    echo "-- ERROR: Ensure that none of the below parameters are Null or Empty for the recreateIDMkeyStore() function:"
    echo "   [path_idmKeystore] is  ${path_idmKeystore}"
    echo "   [idmKeystoreType] is ${idmKeystoreType}"
    echo "   [idmKeystorePwd] length is ${#idmKeystoreType}"
    echo "-- Exiting ..."
    echo ""
    exit 1
  fi

  if [ -f "${path_idmKeystore}" ]; then
    echo "-- Deleting existing keystore ..."
    rm -f "${path_idmKeystore}"
    echo "-- Done"
    echo ""
  fi

  # Adding Certificates to keystore
  createPKCS12addToKeystore "${path_idmKeystore}" "${idmKeystorePwd}" "${idmKeystorePwd}" "${SECRET_CERTIFICATE}" "${SECRET_CERTIFICATE_KEY}" "${CERT_ALIAS}" "${idmKeystoreType}"
  createPKCS12addToKeystore "${path_idmKeystore}" "${idmKeystorePwd}" "${idmKeystorePwd}" "${SECRET_CERTIFICATE_SELFSERVICE}" "${SECRET_CERTIFICATE_SELFSERVICE_KEY}" "selfservice" "${idmKeystoreType}"
  
  # Adding encryption keys to keystore
  addSecretEntryToKeystore "${path_idmKeystore}" "${idmKeystorePwd}" "${idmKeystorePwd}" "${SECRET_ENCKEY_IDM_SELFSERVICE}" "openidm-selfservice-key" "${idmKeystoreType}"
  addSecretEntryToKeystore "${path_idmKeystore}" "${idmKeystorePwd}" "${idmKeystorePwd}" "${SECRET_ENCKEY_IDM_JWTSESSIONHMAC}" "openidm-jwtsessionhmac-key" "${idmKeystoreType}"
  addSecretEntryToKeystore "${path_idmKeystore}" "${idmKeystorePwd}" "${idmKeystorePwd}" "${SECRET_ENCKEY_IDM_SYMDEFAULT}" "openidm-sym-default" "${idmKeystoreType}"

  # Backing up Keystore password
  mkdir -p $(dirname "${path_idmKeystorePwd}")
  echo "${idmKeystorePwd}" > ${path_idmKeystorePwd}
  if [ "$(cat ${path_idmKeystorePwd} | wc -l)" != 1 ]; then
    echo "-- ERROR: Something went wrong while backing up the password"
    echo "   See logs for more details. Exiting ..."
    exit 1
  fi

  echo "-> Updating IDM_ENVCONFIG_DIRS"
  echo "   Current value: ${IDM_ENVCONFIG_DIRS}"
  export IDM_ENVCONFIG_DIRS="${IDM_HOME}/resolver/,${IDM_HOME}/resolver/keystore/"
  echo "   Updated value to: ${IDM_ENVCONFIG_DIRS}"
  echo "-- Done"
  echo ""
}

# ------------------------------------------------------------------------------
# Applies additional recommended ForgeRock Identity Manager (IDM) hardening
# requirements

# Parameters:
#  - ${1}: Path to IDM Keystore file
#  - ${2}: Keystore Password
# ------------------------------------------------------------------------------
function applyIdmDefaultHardening() {
  if [ -n "${1}" ] && [ -n "${2}" ]; then
    local path_idmKeystore="${1}"
    local idmKeystorePwd="${2}"
    local idmKeystoreType="JCEKS"
    local path_configSecretStores="${IDM_HOME}/conf/secrets.json"
    local path_configProps="${IDM_HOME}/conf/config.properties"

    echo "Hardening IDM"
    echo "-------------"
    echo "> path_idmKeystore is '${path_idmKeystore}'"
    echo "> idmKeystoreType is '${idmKeystoreType}'"
    echo "> idmKeystorePwd length is '${#idmKeystorePwd}'"
    echo ""

    echo "-> Disable the generation of default keys in Keystore"
    if [ -f "${path_configSecretStores}" ]; then
      echo "-- Disabling feature"
      json_configProps=$(cat "${path_configSecretStores}" | jq ".populateDefaults=\"false\"")
      echo "-- Done"
      echo ""
    else
      echo "-- ERROR: ${path_configSecretStores} NOT found"
      echo "-- Exiting ..."
      exit 1
    fi

    recreateIDMkeyStore "${path_idmKeystore}" "${idmKeystoreType}" "${idmKeystorePwd}"
    if [ -f "${path_configProps}" ]; then
      echo "-> Enabling HTTPS in '${path_configProps}'"
      sed -i "s/org.osgi.service.http.enabled=&{openidm.http.enabled|true}/org.osgi.service.http.enabled=false/g" "${path_configProps}"
      sed -i "s/org.osgi.service.http.secure.enabled=&{openidm.https.enabled|true}/org.osgi.service.http.secure.enabled=true/g" "${path_configProps}"
      echo "-- Done"
      echo ""
    else
      echo "-- ERROR: ${path_configProps} NOT found"
      echo "-- Exiting ..."
      exit 1
    fi
  else
    echo "-- ERROR: One of the below input variables were EMPTY:"
    echo "     > {1} IDM Keystore is '${1}'"
    echo "     > {2} IDK Keystore  length is '${#idmKeystorePwd}'"
    echo "-- Exiting ...."
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# Update IDM Truststore

# Parameters:
#  - ${1}: Path to IDM Truststore file
#  - ${2}: Truststore Password (current)
#  - ${3}: Truststore Password (new)
# ------------------------------------------------------------------------------
function updateTruststore(){
  if [ -n "${1}" ] && [ -n "${2}" ] && [ -n "${3}" ]; then
    local path_idmTruststore="${1}"
    local idmTruststorePwdCurr="${2}"
    local idmTruststorePwdNew="${3}"
    local path_storepass="${IDM_HOME}/security/storepass"
    
    if [ ! -f "${path_idmTruststore}" ]; then
      showMessage "'${path_idmTruststore}' NOT found." "error" "true"
    else
      changeTrustStorePassword "${path_idmTruststore}" "${idmTruststorePwdCurr}" "${idmTruststorePwdNew}"
      # Backing up Keystore password
      echo "${idmTruststorePwdNew}" > "${path_storepass}"
      [ ! -f "${path_storepass}" ] &&  showMessage "'${path_storepass}' NOT found." "error" "true"
    fi
  else
    echo "-- ERROR: One of the below input variables were EMPTY:"
    echo "     > {1} IDM Truststore is '${1}'"
    echo "     > {2} IDK Truststore Password (current) length is '${#idmTruststorePwdCurr}'"
    echo "     > {3} IDK Truststore Password (new) length is '${#idmTruststorePwdNew}'"
    echo "-- Exiting ...."
    exit 1
  fi
}