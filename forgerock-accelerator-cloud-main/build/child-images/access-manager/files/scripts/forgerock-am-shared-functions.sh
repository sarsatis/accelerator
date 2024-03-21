#!/usr/bin/env bash
# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

# Script to support the execution of the ForgeRock Access Management
# Kubernetes container on startup.

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

source "${MIDSHIPS_SCRIPTS}/tomcat-shared-functions.sh"

path_tmpFolder="/tmp/am"
echo "-> Creating Temp Folder '${path_tmpFolder}'"
mkdir -p "${path_tmpFolder}"
echo "-- Done"
echo ""

# ----------------------------------------------------------------------------------
# Re-creates the default required Keys that are deployed in a Access Manager
# Keystore  by default
#
# Parameters:
#  - ${1}: Path to AM Keystore file
#  - ${2}: Keystore type. E.g. JCEKS, JKS, etc.
#  - ${3}: Location of AM .keypass file
#  - ${4}: Location of AM .storepass file
# ----------------------------------------------------------------------------------
function recreateAMkeysInStore() {
  local path_amKeystore="${1}"
  local amKeystoreType="${2}"
  local amKeypass=${3}
  local amStorepass=${4}
  local errorFound="false"
  local certDetails="/C=GB/ST=London/L=London/O=Midships/OU=IT Department/CN="
  local path_tmp01="/tmp"
  local path_certPub=
  local path_certPri=
  local rootSection=
  echo "[ Re-creating AM Certificate and Secrets Aliases in Keystore (${path_amKeystore}) ]"
  echo ""

  if [ -z "${path_amKeystore}" ] || [ -z "${amKeypass}" ] || [ -z "${amStorepass}" ] || \
     [ -z "${amKeystoreType}" ] || [ "${amKeystoreType}" == "null" ]; then
    echo "-- ERROR: Ensure that none of the below parameters are Null or Empty:#"
    echo "   [amKeystoreType] is '${amKeystoreType}'"
    echo "   [amKeypass] is '${amKeypass}'"
    echo "   [path_amKeystore] is '${path_amKeystore}'"
    echo "   [amKeypass] is '${amKeypass}'"
    echo "   [amStorepass] is '${amStorepass}'"
    echo ""
    errorFound="true"
  fi

  if [ "${errorFound}" == "false" ]; then
    echo "-> Generating Access Manager(AM) Keystore Certificates"
    
    rootSection="es256test"
    path_certPri="${path_tmp01}/${rootSection}-key.pem"
    path_certPub="${path_tmp01}/${rootSection}.pem"
    openssl req -x509 -nodes -days 3660 -sha1 -newkey ec:<(openssl ecparam -name prime256v1) -keyout "${path_certPri}" -out "${path_certPub}" -subj "${certDetails}${rootSection}" 2> /dev/null
    createPKCS12addToKeystore "${path_amKeystore}" "${amStorepass}" "${amKeypass}" "$(cat ${path_certPub} | base64)" "$(cat ${path_certPri} | base64)" "${rootSection}" "${amKeystoreType}"
    rm "${path_certPri}" "${path_certPub}"

    rootSection="es384test"
    path_certPri="${path_tmp01}/${rootSection}-key.pem"
    path_certPub="${path_tmp01}/${rootSection}.pem"
    openssl req -x509 -nodes -days 3660 -sha1 -newkey ec:<(openssl ecparam -name secp384r1) -keyout "${path_certPri}" -out "${path_certPub}" -subj "${certDetails}${rootSection}" 2> /dev/null
    createPKCS12addToKeystore "${path_amKeystore}" "${amStorepass}" "${amKeypass}" "$(cat ${path_certPub} | base64)" "$(cat ${path_certPri} | base64)" "${rootSection}" "${amKeystoreType}"
    rm "${path_certPri}" "${path_certPub}"

    rootSection="es512test"
    path_certPri="${path_tmp01}/${rootSection}-key.pem"
    path_certPub="${path_tmp01}/${rootSection}.pem"
    openssl req -x509 -nodes -days 3660 -sha1 -newkey ec:<(openssl ecparam -name secp521r1) -keyout "${path_certPri}" -out "${path_certPub}" -subj "${certDetails}${rootSection}" 2> /dev/null
    createPKCS12addToKeystore "${path_amKeystore}" "${amStorepass}" "${amKeypass}" "$(cat ${path_certPub} | base64)" "$(cat ${path_certPri} | base64)" "${rootSection}" "${amKeystoreType}"
    rm "${path_certPri}" "${path_certPub}"

    rootSection="test"
    path_certPri="${path_tmp01}/${rootSection}-key.pem"
    path_certPub="${path_tmp01}/${rootSection}.pem"
    openssl req -x509 -nodes -days 3660 -new -newkey rsa:4096 -sha256 -keyout "${path_certPri}" -out "${path_certPub}" -subj "${certDetails}${rootSection}" 2> /dev/null
    createPKCS12addToKeystore "${path_amKeystore}" "${amStorepass}" "${amKeypass}" "$(cat ${path_certPub} | base64)" "$(cat ${path_certPri} | base64)" "${rootSection}" "${amKeystoreType}"
    rm "${path_certPri}" "${path_certPub}"

    echo "-- selfserviceenc ..."
    rootSection="selfserviceenc"
    # Adding aliases for Certs to keystore
    createPKCS12addToKeystore "${path_amKeystore}" "${amStorepass}" "${amKeypass}" "${SECRET_CERTIFICATE_SELFSERVICEENC}" "${SECRET_CERTIFICATE_SELFSERVICEENC_KEY}" "selfserviceenctest" "${amKeystoreType}"
    createPKCS12addToKeystore "${path_amKeystore}" "${amStorepass}" "${amKeypass}" "${SECRET_CERTIFICATE_RSAJWTSIGN}" "${SECRET_CERTIFICATE_RSAJWTSIGN_KEY}" "rsajwtsigningkey" "${amKeystoreType}"
    
    # Adding aliases for Secret entries to keystore
    addSecretEntryToKeystore "${path_amKeystore}" "${amStorepass}" "${amKeypass}" "${SECRET_ENCKEY_SELFSERVICESIGN}" "selfservicesigntest" "${amKeystoreType}"
    addSecretEntryToKeystore "${path_amKeystore}" "${amStorepass}" "${amKeypass}" "${SECRET_ENCKEY_HMACSIGN}" "hmacsigningtest" "${amKeystoreType}"
    addSecretEntryToKeystore "${path_amKeystore}" "${amStorepass}" "${amKeypass}" "${SECRET_ENCKEY_DIRECT}" "directenctest" "${amKeystoreType}"

    echo "-> Adding Store and Key Pass"
    path_tmp01="${AM_PATH_KEYSTORES}/.storepass"
    echo -n "${amStorepass}" > "${path_tmp01}"
    chmod 400 "${path_tmp01}"
    echo "-- Created ${path_tmp01}"
    path_tmp01="${AM_PATH_KEYSTORES}/.keypass"
    echo -n "${amKeypass}" > "${path_tmp01}"
    chmod 400 "${path_tmp01}"
    echo "-- Created ${path_tmp01}"
    echo "-- Done"
    echo ""
  fi
  if [ "${errorFound}" == "true" ]; then
    echo "-- See above logs for details on ERROR(s)"
    echo "   Exiting ...."
    exit 1
  fi
}

# ----------------------------------------------------------------------------------
# Creates a new Keystore,storepass and keypass forr a Access Manager instance
# and delete the original default Keystore, storepass and keypass
#
# Parameters:
#  - ${1}: AM Keystore Password
#  - ${2}: AM Keystore Key Password
# ----------------------------------------------------------------------------------
function createAMkeystoreAndSecrets() {
  echo "Creating Access Manager(AM) Keystore and Secrets"
  echo "------------------------------------------------"
  echo ""
  local path_amKeystoreType="JCEKS"
  local path_amSecretStoreDir_encrypt="${AM_PATH_SECRETS_ENCRYPTED}"
  local path_amSecretStoreDir_default="${AM_PATH_SECRETS_DEFAULT}"
  local path_amKeystore_new="${AM_PATH_KEYSTORES}/keystore.jceks"
  local path_amKeystoreBoot_new="${AM_PATH_KEYSTORES}/boot/keystore.jceks"
  local path_amStorepass_new="${path_amSecretStoreDir_default}/.storepass"
  local path_amKeypass_new="${path_amSecretStoreDir_default}/.keypass"
  local path_amSecretsEntrypass_new="${path_amSecretStoreDir_encrypt}/entrypass" # Filename should have no special characters
  local path_amSecretsStorepass_new="${path_amSecretStoreDir_encrypt}/storepass" # Filename should have no special characters
  local keystorePwd=
  local keystoreKeyPwd=
  local errorFound="false"
  local path_tmp01=

  # Clean up previous folders
  rm -rf "${AM_PATH_SECRETS_ENCRYPTED}" "${AM_PATH_SECRETS_DEFAULT}" "${AM_PATH_KEYSTORES}"

  [ ! -d "${AM_PATH_KEYSTORES}" ] && mkdir -p "${AM_PATH_KEYSTORES}"
  [ ! -d "${AM_PATH_KEYSTORES}/boot" ] && mkdir -p "${AM_PATH_KEYSTORES}/boot"
  [ ! -d "${path_amSecretStoreDir_encrypt}" ] && mkdir -p "${path_amSecretStoreDir_encrypt}"
  [ ! -d "${path_amSecretStoreDir_default}" ] && mkdir -p "${path_amSecretStoreDir_default}"

  if [ -n "${1}" ] && [ -n "${2}" ]; then
    keystorePwd="${1}"
    keystoreKeyPwd="${2}"
    echo "-> Creating Store Pass"
    echo -n "${keystorePwd}" > "${path_amStorepass_new}"
    chmod 400 "${path_amStorepass_new}"
    echo "-- Created ${path_amStorepass_new}"
    echo "${keystorePwd}" | am-crypto encrypt des > "${path_amSecretsStorepass_new}"
    echo "-- Created ${path_amSecretsStorepass_new}"
    echo "-- Done"
    echo ""
    echo "-> Creating Key Pass"
    echo -n "${keystoreKeyPwd}" > "${path_amKeypass_new}"
    chmod 400 "${path_amKeypass_new}"
    echo "-- Created ${path_amKeypass_new}"
    echo "${keystoreKeyPwd}" | am-crypto encrypt des > "${path_amSecretsEntrypass_new}"
    echo "-- Created ${path_amSecretsEntrypass_new}"
    echo "-- Done"
    echo ""

    recreateAMkeysInStore "${path_amKeystore_new}" "${path_amKeystoreType}" "${keystoreKeyPwd}" "${keystorePwd}"

    echo "-> Creating Boot Keystore"
    keystorePwd="$(generateRandomString)"
    keystoreKeyPwd="$(generateRandomString)"
    $(echo generateRandomString | keytool -importpass -alias dsameUserPwd -keystore "${path_amKeystoreBoot_new}" -storetype jceks -storepass "${keystorePwd}" -keypass "${keystoreKeyPwd}" 2> /dev/null)
    $(echo generateRandomString | keytool -importpass -alias configStorePwd -keystore "${path_amKeystoreBoot_new}" -storetype jceks -storepass "${keystorePwd}" -keypass "${keystoreKeyPwd}" 2> /dev/null)
    path_tmp01="${AM_PATH_KEYSTORES}/boot/.storepass"
    echo -n "${keystorePwd}" > "${path_tmp01}"
    chmod 400 "${path_tmp01}"
    echo "-- Created ${path_tmp01}"
    path_tmp01="${AM_PATH_KEYSTORES}/boot/.keypass"
    echo -n "${keystoreKeyPwd}" > "${path_tmp01}"
    chmod 400 "${path_tmp01}"
    echo "-- Created ${path_tmp01}"
    echo "-- Done"
    echo ""
  else
    echo "-- ERROR: Either one or more of the below variables are empty:"
    echo "   > keystorePwd length is ${#keystorePwd}"
    echo "   > keystoreKeyPwd length is ${#keystoreKeyPwd}"
    errorFound="true"
  fi
  if [ "${errorFound}" == "true" ]; then
    echo "-- See above logs for details on ERROR(s)"
    echo "   Exiting ...."
    exit 1
  fi
}

# ----------------------------------------------------------------------------------
# Create a AM cookie file following a login attempt
#
# Parameters:
# - ${1}: AM server URL including URI
# - ${2}: AM Admin Password
# - ${3}: AM Cookie file full path
# ----------------------------------------------------------------------------------
function getAMCookieFile() {
  echo "-> Entered function getAMCookieFile()"
  local amServerUrl="${1}"
  local tmpAMadminPwd="${2}"
  local path_amCookieFile="${3}"
  local httpCode="000"
  local reAuth="true"
  local executionCounter=0
  local tokenId="null"
  local errorFound="false"
  local sucessfulLogin="false"

  if [ -z "${3}" ]; then path_amCookieFile="${path_tmpFolder}/cookie.txt"; fi

  if [ -n "${1}" ] && [ -n "${2}" ] && [ -n "${3}" ]; then
    echo "-- Cookie file Path is ${path_amCookieFile}"
    echo ""
    checkServerIsAlive --svc "${amServerUrl}/json/health/live" --type "url"

    if [ -f "${path_amCookieFile}" ]; then
      echo "-- Cookie file exists. Validating session ...'"
      httpCode=$(curl  -sk --request GET -o /dev/null -w "%{http_code}" \
        --header "Content-Type:application/json" --cookie "${path_amCookieFile}" \
        "${amServerUrl}/json/global-config/realms?_queryFilter=true")
      httpCode="${httpCode:0:3}"
      echo "-- Check returned HTTP Code '${httpCode}'"
      if [ -n "${httpCode}" ] && [ "${httpCode}" == "200" ]; then
        echo "-- Session is valid. Using existing Cookie file"
        reAuth="false"
      else
        echo "-- WARN: Session is NOT valid. Will re-authenticate"
        rm -f "${path_amCookieFile}";
        echo "-- Deleted exixting Cookie file"
        reAuth="true"
      fi
    fi

    if [ "${reAuth}" == "true" ]; then
      echo "-- Creating Cookie file ..."
      while [[ "${sucessfulLogin}" == "false" ]]; do
        verifyAmLogin sucessfulLogin "${serverUrl}" "${path_amCookieFile}" "amadmin" "${defaultAmAdminPwd}"
        executionCounter=$((executionCounter+1))
        echo -n "-- (${executionCounter}) Authenticating ... "
        if [ "${sucessfulLogin}" == "false" ]; then
          if [ "${executionCounter}" -eq "5" ]; then
            echo ""
            echo "-- ERROR: Cannot authenticate with Access Manager. Step required to create Cookie file."
            errorFound="true"
          fi
          sleep 5
          echo "Trying again ..."
        fi
      done
    fi
    echo "-- Done"
    echo ""
  else
    echo "-- ERROR: One of the below input variables were EMPTY:"
    echo " > {1} amServerUrl ${1}"
    echo " > {2} tmpAMadminPwd length is ${#2}"
    echo " > {3} path_amCookieFile is ${3}"
    errorFound="true"
  fi

  if [ "${errorFound}" == "true" ]; then
    echo "-- See above logs for details on ERROR(s)"
    echo "   Exiting ...."
    exit 1
  fi
}

# ----------------------------------------------------------------------------------
# Verify user can log into the Access Manager
#
# Parameters:
# - ${1}: Secuessfull Auth return value. E.g. 'true' or 'false'
# - ${2}: AM Server URL including URI
# - ${3}: Path to AM Cookie File to be created
# - ${4}: AM Username
# - ${5}: AM User Passwword
# ----------------------------------------------------------------------------------
function verifyAmLogin() {
  local serverUrl="${2}"
  local path_amCookieFile="${3}"
  local amUname="${4}"
  local amPword="${5}"
  local sucessfulAuth="true"
  local tmpToken=

  checkServerIsAlive --svc "${serverUrl}" --type "url" --resCodeExpected "302"
  echo "-> Authenticating with Access Manager (AM) as User '${amUname}'"
  if [ -z "${serverUrl}" ] ||  [ -z "${path_amCookieFile}" ] ||  [ -z "${amUname}" ] ||  [ -z "${amPword}" ]; then
    echo "-- ERROR: Either one or more of the below parameters is/are empty:"
    echo "   > serverUrl: '${serverUrl}'"
    echo "   > path_amCookieFile: '${path_amCookieFile}'"
    echo "   > amUname: '${amUname}'"
    echo "   > amPword length: '${#amPword}'"
    echo "   Exiting ..."
    sucessfulAuth="false"
    exit 1
  fi

  tmpToken=$(curl -sk --request POST --header 'Accept-API-Version: resource=2.1' \
    --header 'Content-Type: application/json' --header "X-OpenAM-Username: ${amUname}" \
    --header "X-OpenAM-Password: ${amPword}" -c "${path_amCookieFile}" \
    "${serverUrl}/json/realms/root/authenticate" | jq -r '.tokenId')
  echo "-- Session token is ${tmpToken}"
  
  if [ -z "${tmpToken}" ] || [ "${tmpToken}" == "null" ]; then
    echo "-- ERROR: Access Manager Login FAILED."
    echo "-- Attempting to print out all logs in '${AM_HOME}/var/debug'"
    cat ${AM_HOME}/var/debug/*
    sucessfulAuth="false"
  else
    echo "-- Access Manager(AM) Login SUCCESSFUL."
    sucessfulAuth="true"

    if [ ! -f "${path_amCookieFile}" ]; then
      echo "-- ERROR: Cookie File '${path_amCookieFile}' does not exists. Enure the base folder exists prior to authentication."
      echo "   Cookie file with valid session required for next set of API calls. Exiting ..."
      exit 1
    fi
  fi
  echo ""
  eval "${1}='${sucessfulAuth}'"
}

# ----------------------------------------------------------------------------------
# This function lists all the Access Manager (AM) vars in the config files
# 
# Parameters:
#  - ${1} path to am configuration files
# ----------------------------------------------------------------------------------
function listRequiredAmVars(){
  local path_amConfigDir="${1}"
  local arr_varsAm=()
  local arr_files=()
  local tmpReqVar=
  local tmpVarSet=
  local missingVar="false"
  local prevEnvVar=
  if [ ! -d "${path_amConfigDir}" ]; then 
    echo "-- ERROR: path_amConfigDir '${path_amConfigDir}' was NOT found. Exiing ..."
    exit 1
  fi 
  cd "${path_amConfigDir}"
  arr_files=($(find . -type f -name "*"))
  for file in "${arr_files[@]}"; do
    if [ -f "$file" ]; then
      arr_varsAm+=($(grep -o '\&{[a-zA-Z_][a-zA-Z_0-9.|\:\-\+]*}' "${file}"))
    fi
  done
  arr_varsAm=($(printf "%s\n" "${arr_varsAm[@]}" | sort -u)) #Remove duplicates 1st attempt
  echo "Config Directory: '${path_amConfigDir}'"
  echo "======================================================================================================================================================="
  echo "'${#arr_files[@]}' configuration files found. '${#arr_varsAm[@]}' variables found in configuration files."
  echo "---------- -------------------------------------------------------------- -----------------------------------------------------------------------------"
  echo "<set/not> : <am-variable-name>                                           : <required-env-variable>                                     : <default-set>"
  echo "---------- -------------------------------------------------------------- -----------------------------------------------------------------------------"
  if [ -n "${arr_varsAm}" ]; then
    for amVar in "${arr_varsAm[@]}"; do
      defaultVal="$(echo ${amVar} | grep -o '|[a-zA-Z_][a-zA-Z_0-9.|\:\-\+]*\b')"
      [ -z "${defaultVal}" ] && defaultVal="$(echo ${amVar} | grep -o '|')"
      amVar="${amVar//${defaultVal}/}" #Removing |AnyValue from variable name if exists
      tmpVarSet="  SET  "
      tmpReqVar="${amVar//./_}"
      tmpReqVar="${tmpReqVar//|[a-zA-Z0-9_.:]*/}"
      tmpReqVar="${tmpReqVar//\&/}"
      tmpReqVar="${tmpReqVar//\{/}"
      tmpReqVar="${tmpReqVar//\}/}"
      tmpReqVar="${tmpReqVar^^}"
      if [ -z ${!tmpReqVar+x} ] && [ -z "${defaultVal}" ]; then
        tmpVarSet="NOT-SET"
        missingVar="true"
      fi
      defaultVal=": ${defaultVal//|/}"
      [ "${tmpReqVar}" != "${prevEnvVar}" ] && echo "$(printf %-9s ${tmpVarSet}) : $(printf %-60s ${amVar}) : $(printf %-60s ${tmpReqVar}) ${defaultVal}"
      prevEnvVar="${tmpReqVar}"
    done
    echo ""
    if [ "${missingVar}" == "true" ]; then
      echo "-- ERROR: Missing variables required in Access Manager (AM) configuration found."
      echo "   See above details. Please resolve. Exiting ..."
      exit 1
    fi
  fi
}

# ----------------------------------------------------------------------------------
# NOTE: The below function template was taken from ForgeRock ForgeOps repo
#       https://github.com/ForgeRock/forgeops
# Parameters:
#  - ${1}: AM serverURL
#  - "{2}: Cookie file path"
# ----------------------------------------------------------------------------------
function enableRealmAppPolicyStore() {
  local httpCode="000"
  local serverURL="${1}"
  local path_amCookieFile="${2}"
  local errorFound="false"

  if [ -z "${serverURL}" ]; then
    echo "-- ERROR: AM server URL is EMPTY"
    errorFound="true"
  fi

  if [ ! -f "${path_amCookieFile}" ]; then
    echo "-- ERROR: Cookie file '${path_amCookieFile}' NOT found"
    errorFound="true"
  fi

  if [ "${errorFound}" == "true" ]; then
    echo "-- ERROR: Cookie file '${path_amCookieFile}' NOT found. Exiting ..."
    exit 1
  fi

  echo "-> Setup Root Realm External Datastore service"
  httpCode=$(curl -sk -o /dev/null -w "%{http_code}" \
    "${serverURL}/json/realms/root/realm-config/services/DataStoreService?_action=create" \
    -X POST -b "${path_amCookieFile}" \
    -H "Accept-API-Version: protocol=1.0,resource=1.0" \
    -H "Content-Type: application/json" \
    --data-binary "{
      \"applicationDataStoreId\": \"application-store\",
      \"policyDataStoreId\": \"policy-store\"
    }"
  )
  if [[ ${httpCode} -ne 201 ]]; then
    echo -e "\e[31m--Failed to create root realm external datastore service.\e[0m"
    echo "-- HTTP Code returend: ${httpCode}"
    exit 1
  fi
  echo "-- Done"
  echo " "
}

# ----------------------------------------------------------------------------------
# NOTE: The below function template was taken from ForgeRock ForgeOps repo
#       https://github.com/ForgeRock/forgeops. Function to encrypt string using AM 
#       Libraries
# Parameters:
#  - ${1}: 'hash' or 'encrypt'
#  - "{2}: 'des' . Not required if using 'hash'
# Uasge:
# echo "string-toencrypt" | am-crypto hash
# echo "string-toencrypt" | am-crypto encrypt des
# ----------------------------------------------------------------------------------
am-crypto() {
  java -jar ${AM_HOME}/tools/crypto-tool.jar $@
}

# ----------------------------------------------------------------------------------
# This functions add the required certificates to AM Trust and/or Key stores
# 
# Parameters:
#  - ${1} path to am Keystore file
#  - ${2} path to am Truststore file
#  - ${3} Keystore password
#  - ${4} Truststore password
# ----------------------------------------------------------------------------------
function addDataStoreCertsToTrustKeyStore() {
  local errorFound="false"
  local path_secretsUS="/opt/ds/secrets/us"
  local path_secretsTS="/opt/ds/secrets/ts"
  local path_secretsAPS="/opt/ds/secrets/aps"
  local dsTrustedCertsCsv="${SECRET_CERTIFICATE}!${CERT_ALIAS},${SECRET_CERTIFICATE_US}!user-store,${SECRET_CERTIFICATE_TS}!token-store,${SECRET_CERTIFICATE_APS}!app-policy-store"
  local tmpK8sSecretsPathIndx=0
  local path_keystoreFile="${1}"
  local path_truststoreFile="${2}"
  local password_keystore="${3}"
  local password_truststore="${4}"

  [ -f "${path_keystoreFile}" ] && echo "-- ERROR: Keystore '${path_keystoreFile}' exist, deleting ..." && rm -rf "${path_keystoreFile}"
  [ ! -f "${path_truststoreFile}" ] && echo "-- ERROR: Truststore '${path_truststoreFile}' not found." && errorFound="true"
  [ -z "${password_keystore}" ] && echo "-- ERROR: Keystore password is empty." && errorFound="true"
  [ -z "${password_truststore}" ] && echo "-- ERROR: Truststore password is empty." && errorFound="true"

  if [ "${errorFound}" == "false" ]; then
    addCertsToTruststore "${path_truststoreFile}" "${password_truststore}" "${dsTrustedCertsCsv}"
    createPKCS12fromCerts "${CERT_ALIAS}" "${SECRET_CERTIFICATE}" "${SECRET_CERTIFICATE_KEY}" "${path_keystoreFile}" "${password_keystore}"
  fi
  if [ "${errorFound}" == "true" ]; then
    echo "-- ERROR: See above for more details. Exiting ..."
    exit 1
  fi
}

# ----------------------------------------------------------------------------------
# This function manages the setup of the required Applications and Policies 
# configurations in the app-policy-store
# LOAD_APP_POLICIES
# Parameters:
#  - ${1} Current Pod Index
#  - ${2} Load Apps and Policies. E.g. 'true' or 'false'
#  - ${3} Access Manager Server URL
#  - ${4} Application and Policy Store FQDN
#  - ${5} Application and Policy Store Alive endpoint portocol. E.g. http or https
#  - ${6} Application and Policy Store Alive endpoint port
#  - ${7} Space separated Realms to clean up. E.g. "/realm01 /realm02 /relam03"
# ----------------------------------------------------------------------------------
function manageAppsAndPolicies(){
  local podIndx="${1}"
  local loadAppsAndPolicies="${2}"
  local serverUrl_AM="${3}"
  local serverUrl_APS="${4}"
  local protocol_aliveAPS="${5}"
  local port_aliveAPS="${6}"
  local amRealms="${7}"
  echo "Manage Applications and Policies"
  echo "--------------------------------"
  echo "-- This is the 1st Access Manager Pod with index ${podIndx}"
  echo "   > loadAppsAndPolicies: '${loadAppsAndPolicies}'"
  echo "   > App Policy Store: "
  echo "     - FQDN: '${serverUrl_APS}'"
  echo "     - PROTOCOL: '${protocol_aliveAPS}'"
  echo "     - PORT: '${port_aliveAPS}'"
  echo "  > AM Server:"
  echo "    - URL: '${serverUrl_AM}'"
  echo "    - REALM(S): '${amRealms}'"
  echo ""
  if [ ${podIndx} -eq 0 ] && [ "${loadAppsAndPolicies}" == "true" ]; then   
    checkServerIsAlive --svc "${serverUrl_APS}" --type "ds" --channel "https" --port "${HTTPS_PORT_APS}"

    if [ -n "${amRealms}" ] && [ -n "${serverUrl_AM}" ]; then
      clearExistingAppsAndPolicies "${serverUrl_AM}" "${amRealms}"
    else
      echo "-- ERROR: Either the 'AM Server URL' or/and 'AM Realms' is/are empty."
      echo "          Skipping clearing of Apps and Policies."
    fi
    if [ -n "${serverUrl_AM}" ]; then
      importAppsAndPolicies "${serverUrl_AM}"
    fi
  else
    echo "-- INFO: Skipping processing of Apps and Policies for either of the below reasons:"
    echo "       > This is not the 1st Access Manager Pod"
    echo "       > loadAppsAndPolicies is not set to 'true'"
    echo "-- Done"
    echo ""
  fi
}

# ----------------------------------------------------------------------------------
# This clears provided Applications and Policies configurations from app-policy-store
# 
# Parameters:
#  - ${1} Access Manager Server URL
#  - ${2} Space separated Realms to clean up. E.g. "/realm01 /realm02 /relam03"
# ----------------------------------------------------------------------------------
function clearExistingAppsAndPolicies(){
  local path_amsterHome="${AM_HOME}/tools/amster"
  local path_amsterRSAkey="${AM_PATH_SECURITY}/keys/amster/amster_rsa"
  local path_tmpDir="/tmp/amster"
  local path_amsterLogFile="${path_tmpDir}/amster.log"
  local path_configToImport="${AM_PATH_CONFIG}/amster"
  local skipProcessing="false"
  local path_appPoliciesAmsterClear_original="${AM_HOME}/scripts/remove-app-policies.amster"
  local path_appPoliciesAmsterClear_updated="${AM_HOME}/scripts/remove-app-policies-updated.amster"
  local path_appPoliciesAmsterClear_toexec="${AM_HOME}/scripts/remove-app-policies-toexecute.amster"
  local amServerUrl="${1}"
  local amRealms="${2}"

  echo "[ Removing Applications and Policies ]"
  echo ""
  echo "-> Creating required folders ..."
  mkdir -p "${path_tmpDir}"
  echo "-- Done"
  echo ""

  echo "-> Validating variables ..."
  if [ -z "${amServerUrl}" ]; then
    echo "-- ERROR: amServerUrl is empty."
    skipProcessing="true"
  fi
  if [ -z "${amRealms}" ]; then
    echo "-- ERROR: '${amRealms}' is Empty. Expected format is '/realm01 /real02 /realm03 etc'"
    skipProcessing="true"
  fi
  if [ ! -f "${path_amsterRSAkey}" ]; then
    echo "-- ERROR: Amster key '${path_amsterRSAkey}' NOT found"
    skipProcessing="true"
  fi
  if [ ! -d "${path_configToImport}" ]; then
    echo "-- WARN: '${path_configToImport}' does NOT exists."
    skipProcessing="true"
  fi
  echo "-- Done"
  echo ""

  if [ -n "${amRealms}" ]; then
    echo "-> Updating Amster Apps Policies Clear script at '${path_appPoliciesAmsterClear_original}'"
    IFS=' ' read -ra arrAmRealms <<< "${amRealms}"

    if [ ! -f "${path_appPoliciesAmsterClear_original}" ]; then
      echo "-- ERROR: File '${path_appPoliciesAmsterClear_original}' not found."
      skipProcessing="true"
    else
      [ -f "${path_appPoliciesAmsterClear_updated}" ] &&  rm "${path_appPoliciesAmsterClear_updated}";
      [ -f "${path_appPoliciesAmsterClear_toexec}" ] &&  rm "${path_appPoliciesAmsterClear_toexec}";

      for realm in "${arrAmRealms[@]}"
      do
        echo "-- Processing for Realm: ${realm}"
        echo "-- Creating version to execute ..."
        cp -p "${path_appPoliciesAmsterClear_original}" "${path_appPoliciesAmsterClear_updated}"
        echo "-- Updating AM Server URL placeholder to '${amServerUrl}'"
        sed -i "s+%AM_SERVER_URL%+${amServerUrl}+g" "${path_appPoliciesAmsterClear_updated}"
        echo "-- Updating Amster RSA key plaeholder to '${path_amsterRSAkey}'"
        sed -i "s+%PATH_AMSTER_RSA_KEY%+${path_amsterRSAkey}+g" "${path_appPoliciesAmsterClear_updated}"
        echo "-- Updating AM Realm plaeholder to '${realm}'"
        sed -i "s+%AM_REALM%+${realm}+g" "${path_appPoliciesAmsterClear_updated}"
        echo "-- Adding to final sctipt for execution ..."
        cat "${path_appPoliciesAmsterClear_updated}" >> "${path_appPoliciesAmsterClear_toexec}"
      done
    fi
    echo "-- Done"
    echo ""
  fi

  if [ ! -f "${path_appPoliciesAmsterClear_toexec}" ]; then
    echo "-- WARN: Amster script '${path_appPoliciesAmsterClear_toexec}' NOT created."
    echo "         No Amster commads to execute."
    skipProcessing="true"
  fi

  if [ "${skipProcessing}" == "false" ]; then
    # From this point it is assumed the Access Manager is alive
    # Code referenced from https://github.com/ForgeRock/forgeops
    echo "-> Executing amster to clear app-policy-store data ..."
    ${path_amsterHome}/amster -q "${path_appPoliciesAmsterClear_toexec}" > "${path_amsterLogFile}" 2>&1
    cat "${path_amsterLogFile}"
    echo ""
    # This is a workaround to test if the import failed, and return a non zero exit code if it did
    # See https://bugster.forgerock.org/jira/browse/OPENAM-11431
    if grep -q 'ERROR\|Configuration\ failed\|Could\ not\ connect\|No\ connection\|Unexpected\ response' <${path_amsterLogFile}; then
      echo "-- ERROR: See above logs for more info on errors."
    fi
  else
    echo "-- WARN: Amster script execution. See above logs for more info."
  fi
  echo ""

  echo "-> Cleaning up"
  rm -rf "${path_tmpDir}"
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This imports exports amster Applications and Policies configurations
# 
# Parameters:
#  - ${1} Access Manager Server URL
# ----------------------------------------------------------------------------------
function importAppsAndPolicies(){
  local path_amsterHome="${AMSTER_HOME}"
  local path_amsterRSAkey="${AM_PATH_SECURITY}/keys/amster/amster_rsa"
  local path_tmpDir="/tmp/amster"
  local path_amstercript="${path_tmpDir}/configureAM.amster"
  local path_amsterLogFile="${path_tmpDir}/amster.log"
  local path_configToImport="${AM_PATH_CONFIG}/amster"
  local skipProcessing="false"
  local amServerUrl="${1}"
  
  echo "[ Loading Applications and Policies ]"
  echo "  From: Config to import: ${path_configToImport}"
  echo "" 
  
  echo "-> Creating required folders ..."
  mkdir -p "${path_tmpDir}"
  echo "-- Done"
  echo ""

  echo "-> Validating variables ..."
  if [ -z "${amServerUrl}" ]; then
    echo "-- ERROR: amServerUrl is empty."
    skipProcessing="true"
  fi
  if [ ! -f "${path_amsterRSAkey}" ]; then
    echo "-- ERROR: Amster key '${path_amsterRSAkey}' NOT found"
    skipProcessing="true"
  fi
  if [ ! -d "${path_configToImport}" ]; then
    echo "-- WARN: '${path_configToImport}' does NOT exists."
    skipProcessing="true"
  fi
  {
    echo "connect \"${amServerUrl}\" -k \"${path_amsterRSAkey}\""
    echo "import-config --path \"${path_configToImport}\" --clean false"
    echo ':exit;'
  } >> "${path_amstercript}"
  if [ ! -f "${path_amstercript}" ]; then
    echo "-- WARN: Amster script '${path_amstercript}' does NOT exists."
    skipProcessing="true"
  fi
  echo "-- Done"
  echo ""

  if [ "${skipProcessing}" == "false" ]; then
    # From this point it is assumed the Access Manager is alive
    # Code referenced from https://github.com/ForgeRock/forgeops
    echo "-> Executing amster import ..."
    ${path_amsterHome}/amster -q "${path_amstercript}" > "${path_amsterLogFile}" 2>&1
    cat "${path_amsterLogFile}"
    echo "-- Done"
    # This is a workaround to test if the import failed, and return a non zero exit code if it did
    # See https://bugster.forgerock.org/jira/browse/OPENAM-11431
    if grep -q 'ERROR\|Configuration\ failed\|Could\ not\ connect\|No\ connection\|Unexpected\ response' <${path_amsterLogFile}; then
      echo "-- ERROR: See above logs for more info on errors."
    fi
  else
    echo "-- WARN: Skipping import. See above logs for more info."
  fi
  echo ""

  echo "-> Cleaning up"
  rm -rf "${path_tmpDir}"
  echo "-- Done"
  echo ""
}

function cleanUpDeployFiles(){
  echo "Cleaning up"
  echo "-----------"
  # echo "-> Unsetting environment variables with clear secrets"
  # unsetEnvVarsWithSecerts
  # echo "-- Done"
  # echo ""
  echo "-> Clearing ${path_tmpFolder} folder"
  rm -rf ${path_tmpFolder}
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This imports exports amster Applications and Policies configurations
# 
# Parameters:
#  - ${1} Access Manager protocol. Allowed 'http' or 'https'
#  - ${2} Access Manager Load Balancer Domain
#  - ${3} Access Manager Server Port
#  - ${4} Access Manager URI
# ----------------------------------------------------------------------------------
function makeServerFqdnSameAsSite(){
  local errorFound="false"
  local currAmProtocol="http"
  local currServerFQDN="amserver"
  local currServerPort="8080"
  local currAmUri="am"
  local path_tmp01=""
  local path_tmp02=""
  local tmpStr01=""
  local tmpStr02=""
  local newAmProtocol="${1}"
  local newAmLbDomain="${2}"
  local newAmPort="${3}"
  local newAmUri="${4}"

  echo "Update AM Server URL to align with Site"
  echo "---------------------------------------"
  echo "Current AM Server FQDN: ${currServerFQDN}"
  echo "Curent AM Site FQDN: ${newAmLbDomain}"
  echo "New Server Protocol: ${newAmProtocol}"
  echo "New Server Port: ${newAmPort}"
  echo "New Server URI: ${newAmUri}"
  echo " "

  if [ "${newAmProtocol,,}" != "http"  ] && [ "${newAmProtocol,,}" != "https"  ]; then
    echo "-- ERROR: AM Server Protocol provided '${newAmProtocol}' is not 'http' or 'https'."
    errorFound="true"
  else
    newAmProtocol="${newAmProtocol,,}"
  fi
  if [ -z "${newAmLbDomain}" ]; then
    echo "-- ERROR: Current AM Load Balancer Domain provided is empty."
    errorFound="true"
  fi
  if [ -z "${newAmPort}" ]; then
    echo "-- ERROR: AM Server port provided is empty."
    errorFound="true"
  fi

  if [ "${errorFound}" == "false" ]; then
    path_tmp01="${AM_HOME}/config/services/realm/root/iplanetamplatformservice/1.0/globalconfig/default/com-sun-identity-servers"
    filename_source="${currAmProtocol}___${currServerFQDN}_${currServerPort}_${currAmUri}.json"
    filename_dest="${newAmProtocol}___${newAmLbDomain}_${newAmPort}_${newAmUri}.json"
    path_soruce="${path_tmp01}/${filename_source}"
    path_destination="${path_tmp01}/${filename_dest}"    
    echo "-> Updating files and configurations"
    if [ -f "${path_soruce}" ]; then
      echo "-- Renaming primary server file ..."
      mv "${path_soruce}" "${path_destination}"          
      if [ -f "${path_destination}" ]; then
        echo "-- Updating URLs ..."
        strFind="${currAmProtocol}://${currServerFQDN}:${currServerPort}/${currAmUri}"
        strReplace="${newAmProtocol}://${newAmLbDomain}:${newAmPort}/${newAmUri}"
        sed -i "s+$strFind+$strReplace+g" "${path_destination}"
        echo "-- Updating Protocols ..."
        strFind="${currAmProtocol}\""
        strReplace="${newAmProtocol}\""
        sed -i "s+$strFind+$strReplace+g" "${path_destination}"
      else
        echo "-- ERROR: '${path_destination}' NOT created"
        errorFound="true"
      fi
    else
      echo "-- ERROR: '${path_soruce}' not found"
      echo "   Listing directory:"
      ls -ltr "${path_tmp01}"
      errorFound="true"
    fi
    echo " "

    echo "-- Updating protocol in config files"
    find ${AM_PATH_CONFIG}/. -name '*.json' -type f -exec sed -i "s+$currAmProtocol:+$newAmProtocol:+g" {} \;
    echo "-- Updating hostname in config files"
    find ${AM_PATH_CONFIG}/. -name '*.json' -type f -exec sed -i "s+$currServerFQDN+$newAmLbDomain+g" {} \;
    echo "-- Updating Port in config files"
    find ${AM_PATH_CONFIG}/. -name '*.json' -type f -exec sed -i "s+$currServerPort+$newAmPort+g" {} \;
    echo "-- Updating 'boot.json'"
    path_tmp01="${AM_PATH_CONFIG}/boot.json"
    path_tmp02="/tmp/boot.json"
    cat "${path_tmp01}" | \
      jq ".instance=\"${newAmProtocol}://${newAmLbDomain}:${newAmPort}/${newAmUri}\" " > "${path_tmp02}"
    cp "${path_tmp02}" "${path_tmp01}"
    echo " "

    # Updating template(s) with new Server details. (for use later by other components/processes)
    path_placeholderTmpFile="${AM_PATH_TOOLS}/amupgrade/rules/placeholders/7.0.0-placeholders.groovy"
    echo "-- Updating template '${path_placeholderTmpFile##*/}'"
    if [ -f "${path_placeholderTmpFile}" ]; then
      strFind="${currAmProtocol}://${currServerFQDN}:${currServerPort}/${currAmUri}"
      strReplace="${newAmProtocol}://${newAmLbDomain}:${newAmPort}/${newAmUri}"
      sed -i "s+$strFind+$strReplace+g" "${path_placeholderTmpFile}"
    else
      echo "-- ERROR: File '${path_placeholderTmpFile}' was NOT found."
      errorFound="true"
    fi
    path_placeholderTmpFile="${AM_PATH_TOOLS}/serverconfig-modification.groovy"
    echo "-- Updating template '${path_placeholderTmpFile##*/}'"
    if [ -f "${path_placeholderTmpFile}" ]; then
      strFind="${currAmProtocol}://${currServerFQDN}:"
      strReplace="${newAmProtocol}://${newAmLbDomain}:"
      sed -i "s+$strFind+$strReplace+g" "${path_placeholderTmpFile}"
    else
      echo "-- WARN: File '${path_placeholderTmpFile}' was NOT found."
      errorFound="true"
    fi
    echo " "

    echo "-- Updating Tomcat application directory"
    path_tmp01="${CATALINA_HOME}/webapps/${currAmUri}"
    path_tmp02="${CATALINA_HOME}/webapps/${newAmUri}"
    if [ "${currAmUri}" != "${newAmUri}" ]; then
      mv "${path_tmp01}" "${path_tmp02}"
    else
      echo "   No change to URI, leaving as '${newAmUri}'"
    fi
    echo "-- Done"
    echo " "

    echo "-- Updating Base Config :"
    echo "   From: '${AM_PATH_CONFIG}'"
    echo "     To: '${AM_PATH_CONFIG_BASE}'"
    if [ -d "${AM_PATH_CONFIG}" ] && [ -d "${AM_PATH_CONFIG_BASE}" ]; then
      cp -R ${AM_PATH_CONFIG}/. ${AM_PATH_CONFIG_BASE}
      addSharedFile "${AM_PATH_CONFIG}/config-update-done" "am-config-update-done"; # Notify FACT
    else
      echo "-- ERROR: Either '${AM_PATH_CONFIG}' or '${AM_PATH_CONFIG_BASE}' does NOT exists."
    fi
  fi
  if [ "${errorFound}" == "true" ]; then
    echo "-- ERROR: See above for more details. Exiting ..."
    exit 1
  fi
}

# ----------------------------------------------------------------------------------
# This function applies selected bespoke AM settings
# 
# Parameters:
#  - ${1} Access Manager protocol. Allowed 'http' or 'https'
#  - ${2} Access Manager Load Balancer Domain
#  - ${3} Access Manager Server Port
#  - ${4} Access Manager URI
# ----------------------------------------------------------------------------------
function applyBespokeSettings(){
  local serverIndx=$(echo ${HOSTNAME} | grep -Eo '[0-9]+$')
  local lbcookieIndx=$(printf "%02d\n" $((serverIndx)))
  local path_serverProps="${AM_PATH_CONFIG}/services/realm/root/iplanetamplatformservice/1.0/globalconfig/default/com-sun-identity-servers/${AM_SERVER_PROTOCOL,,}___${AM_SERVER_FQDN,,}_${AM_SERVER_PORT}_${AM_URI,,}.json"
  echo "-> Updating Load Balancer Cookie value"
  if [ -f "${path_serverProps}" ]; then
    sed -i "s+com.iplanet.am.lbcookie.value=01+com.iplanet.am.lbcookie.value=${lbcookieIndx}+g" "${path_serverProps}"
    echo "-- Value set to '${lbcookieIndx}'"
  else
    echo "-- ERROR: '${path_serverProps}' NOT found."
  fi
  echo "-- Done"
  echo ""
}