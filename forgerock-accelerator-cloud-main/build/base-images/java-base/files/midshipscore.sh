#!/usr/bin/env bash
# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

# This file contains scripts to configure the base scripts required by
# Midships ForgeRock Accelerator solution.

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
set +H # Disablng Historical Expansion to allow things like ! in varibles
set -E # Any trap on ERR is inherited by shell functions. same as: set -o errtrace
set +o pipefail +e #script exits if any command in a pipeline fails and coninues on error

# Global variables
podIndx=$(echo "${HOSTNAME}" | grep -Eo '[0-9]+$')
path_setupLog_AM="${AM_HOME}/setup.log"
path_setupLog_DS="${DS_HOME}/setup.log"
path_setupLog_IDM="${IDM_HOME}/setup.log"
path_setupLog_IG="${IG_HOME}/setup.log"

# -------------------------------------------------------
# Function to install Python
# -------------------------------------------------------
function installPython(){
	echo "-- installing Python"
	apt-get -y install python3
	echo "-- Done"
	echo ""
	echo "-- Making Python 3 Default (Sym Link for python)"
	update-alternatives --install /usr/bin/python python /usr/bin/python3 2
	echo "-- Done"
	echo ""
}

# -------------------------------------------------------
# Function to remove Python
# -------------------------------------------------------
function removePython(){
	echo "-- Removing Python"
	apt-get remove -y python3
	rm -rf /usr/bin/python
	echo "-- Done"
	echo ""
	echo "-- Cleaning up packages"
	apt-get -y clean
	apt-get -y autoremove
	echo "-- Done"
	echo ""
}

# -------------------------------------------------------
# Function to install Cloud Agent (GCP, AWS, AZURE, etc.)

# Parameters:
# ${1} : The Cloud Provider. E.g. aws, gcp, azure, etc.
# ${2} : Temp folder for binary and GCP account access file
# -------------------------------------------------------
function installCloudClient () {
	local cloudProvider=${1}
	local pathTmp=${2}
	echo "-> Entered installCloudClient"
	echo "-- [Inputs]"
	echo "   cloudProvider: ${cloudProvider}"
	echo ""
	mkdir -p "${pathTmp}"
	case ${cloudProvider,,} in
	  "gcp")
			installPython
			echo "-- Dwonloading zip"
			curl -k -o ${pathTmp}/google-cloud-sdk.zip https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.zip
			echo "-- Done"
			echo ""
	    echo "-- Unzipping zip"
	    unzip "${pathTmp}/google-cloud-sdk.zip" -d /opt/
			echo "-- Done"
			echo ""
			echo "-- Installing GOOGLE-CLOUD-SDK CLI"
	    /opt/google-cloud-sdk/install.sh --usage-reporting=true --path-update=true --bash-completion=true --rc-path=/opt/gcloud/.bashrc --disable-installation-options
			export PATH=/opt/google-cloud-sdk/bin:$PATH
			echo "-- Done"
			echo ""
	    echo "-- Updating GCloud components"
	    /opt/google-cloud-sdk/bin/gcloud --quiet components update app preview alpha beta app-engine-java app-engine-python kubectl bq core gsutil gcloud
			echo "-- Done"
			echo ""
	    echo "-- Authenticating with GCloud"
	    gcloud auth activate-service-account --key-file=${pathTmp}/gcp-gcs-service-account.json
			echo "-- Done"
			echo ""
		;;
	  "aws")
			installPython
			echo "-- Installing AWS CLI"
	    pip3 install awscli
	    aws --version
			echo "-- Done"
			echo ""
	  ;;
	  "azure")
	    echo ""
	    ;;
	  *)
			echo "-- Skipping client instalation"
			echo "-- Done"
			echo ""
		;;
	esac
}

# -------------------------------------------------------
# Function to remove Cloud Agent (GCP, AWS, AZURE, etc.)

# Parameters:
# ${1} : The Cloud Provider. E.g. aws, gcp, azure, etc.
# ${2} : Temp folder for binary and GCP account access file
# -------------------------------------------------------
function removeCloudClient () {
	local cloudProvider=${1}
	local pathTmp=${2}
	echo "-> Entered removeCloudClient"
	echo "-- [Inputs]"
	echo "   cloudProvider: ${cloudProvider}"
	echo ""
	mkdir -p "${pathTmp}"
	case ${cloudProvider,,} in
	  "gcp")
			echo "-- Deleting ${pathTmp}/google-cloud-sdk.zip"
      rm -rf "${pathTmp}/google-cloud-sdk.zip"
			echo "-- Done"
			echo ""
			echo "-- Deleting ${pathTmp}/gcp-gcs-service-account.json"
			rm -rf "${pathTmp}/gcp-gcs-service-account.json"
			echo "-- Done"
			echo ""
      echo "-- Deleting '/opt/google-cloud-sdk'"
      rm -drf /opt/google-cloud-sdk
			echo "-- Done"
			echo ""
      echo "-- Deleting '/opt/gcloud'"
      rm -drf /opt/gcloud
			echo "-- Done"
			echo ""
			echo "-- Deleting '~/.config/gcloud'"
      rm -drf '~/.config/gcloud'
			echo "-- Done"
			echo ""
			echo "-- Cleaning 'PATH'"
			export PATH=${PATH/'/opt/google-cloud-sdk/bin:'/}
			removePython
		;;
	  "aws")
			echo "-- Removing AWS CLI"
	    pip3 uninstall awscli
			echo "-- Done"
			echo ""
			echo "-- Clearing ENV variables"
	    unset AWS_ACCESS_KEY_ID
	    unset AWS_SECRET_ACCESS_KEY
			echo "-- Done"
			echo ""
			removePython
	  ;;
	  "azure")
	    echo ""
	  ;;
	  *)
			echo "-- Skipping client removal as none was installed."
			echo "-- Done"
			echo ""
	  ;;
	esac
}

# ------------------------------------------
# Function to get client secrets from Vault
# Parameters:
# ${1} : return_val
# ${2} : Secret URL
# ${3} : Secrets Manager Token
# ${4} : Secrets key/name
# -----------------------------------------
function getSecretFromVault () {
	echo "-> Getting '${4}/${5}'"
	local secret_info=$(curl -sk --header 'X-Vault-Token: '"${3}" \
		--header "X-Vault-Namespace: admin" \
		--request GET "${2}" | jq -r '.data.data.'"${4}")
	# Remove below comment when testing
  # echo "-- Value is $secret_info"
	eval "${1}='${secret_info}'"
  echo "-- Done"
	echo ""
}

# ----------------------------------------------------------------------
# This function checks if a check if a file exists end exits once found.
#
# Parameters:
#  - ${1}: The full path of the file
#  - ${2}: This is a multiplier for the ${checkFrequency}
# ----------------------------------------------------------------------
function checkIfFileExists() {
  local filePathToFind=${1}
  local fileEsistsCounter=1
  local checkFrequency=10
  local sharedFolder="${filePathToFind%/*}"
  if [ -z ${2} ] || [ "${2}" == "null" ]; then
    noOfChecks=30
  else
    noOfChecks=${2}
  fi
  echo ""
  echo "-> Waiting for file (${filePathToFind})"
  if [ ! -d "${sharedFolder}" ]; then
    echo "-- WARN: Directory '${sharedFolder}' does NOT exists."
    echo "         Check above logs as file might NEVER be found."
  fi
  while [ ! -f ${filePathToFind} ]; do
    echo "-- (${fileEsistsCounter}/${noOfChecks}) Waiting ${checkFrequency} seconds ..."
    sleep ${checkFrequency}

    if [ ${fileEsistsCounter} == ${noOfChecks} ]; then
      secondsWaitedFor=$((${checkFrequency} * ${noOfChecks}))
      echo "-- Waited for ${secondsWaitedFor} seconds and no response"
      echo "-- Exiting ..."
      exit 1
    fi
    fileEsistsCounter=$((${fileEsistsCounter} + 1))
  done
  if [ -f "${filePathToFind}" ]; then
    echo "-- File found"
  else
    echo "-- File NOT found. Exiting ..."
    exit 1
  fi
  echo ""
}

# ----------------------------------------------------------------------------------
# This function gets Secrets from a Secrets Manager or Kubernetes Cluster Secrets
# and Config-Maps
#
# Parameters:
#  - ${1}: Return Value. The secret value returned
#  - ${2}: Secrets Source/Mode. Accepted k8s and REST
#  - ${3}: Secrets Manager Base Path/URL
#  - ${4}: Secret Key name to retrieve
#  - ${5}: Secrets Manager REST Token
# NOTE: Do not name local varaible the same as variable for ${1}
# ----------------------------------------------------------------------------------
function getSecret() {
  local tmpSecretsMode="${2}"
  local secretsMngrBasePath="${3}"
  local secretKeyName="${4}"
  local secretsMngrToken="${5}"
  local tmpVal=
  local errFound="false"
  if [ -n "${tmpSecretsMode}" ]; then
    if [ "${tmpSecretsMode^^}" == "REST" ]; then
      if [ -n "${secretsMngrBasePath}" ] && [ -n "${secretsMngrToken}" ] && [ -n "${secretKeyName}" ]; then
        getSecretFromVault tmpVal "${secretsMngrBasePath}" "${secretsMngrToken}" "${secretKeyName}"
      else
        echo "-- ERROR: One of the below required input variables were EMPTY:"
        echo "   > {2} tmpSecretsMode is ${tmpSecretsMode}"
        echo "   > {3} secretsMngrBasePath is ${secretsMngrBasePath}"
        echo "   > {4} secretKeyName is '${secretKeyName}'"
        echo "   > {6} secretsMngrToken is '${secretsMngrToken}'"
        errFound="true"
      fi
    elif [ "${tmpSecretsMode,,}" == "volume" ]; then
      if [ -n "${secretsMngrBasePath}" ] && [ -n "${secretKeyName}" ]; then
		    tmpPathToSecretKey="${secretsMngrBasePath}/${secretKeyName}"
		    if ls ${tmpPathToSecretKey} > /dev/null 2>&1; then
	        tmpVal=$(cat ${tmpPathToSecretKey})
		    else
					echo "-- ERROR: Either the required Folder of File below could not be found:"
					echo "   > Folder required is '${secretsMngrBasePath}'"
					echo "   > File required is '${secretKeyName}'"
					errFound="true"
				fi
      else
        echo "-- ERROR: One of the below required input variables were EMPTY:"
        echo "   > {2} tmpSecretsMode is ${tmpSecretsMode}"
        echo "   > {3} secretsMngrBasePath is '${secretsMngrBasePath}'"
        echo "   > {4} secretKeyName is '${secretKeyName}'"
        errFound="true"
      fi
    else
      echo "-- ERROR: Invalid Secret Mode provided. Expected 'volume' or 'REST'."
      errFound="true"
    fi
    eval "${1}='${tmpVal}'"
  else
    echo "-- ERROR: The provided Secert mode is empty"
    errFound="true"
  fi
  if [ "${errFound}" == "true" ]; then
    echo "-- See above logs for additional info and errors."
    echo "   Exiting ..."
    exit 1
  fi
}

# ----------------------------------------------------------------------------------
# This functions changes the password fo a Java TrustStore
#
# Parameters:
#  - ${path_truststoreFile}: The path to the truststore file
#  - ${pwd_old}: Truststore current password
#  - ${pwd_new}: Truststore new password
# ----------------------------------------------------------------------------------
function changeTrustStorePassword() {
  local errFound="false"
  local path_truststoreFile="${1}"
  local pwd_old="${2}"
	local pwd_new="${3}"
  echo "-- Changing password for '${path_truststoreFile}'"
  [ -z "${pwd_old}" ] && echo "-- ERROR: The Current password provided is empty." && errFound="true"
  [ -z "${pwd_new}" ] && echo "-- ERROR: The New password provided is empty." && errFound="true"
  [ ! -f "${path_truststoreFile}" ] && echo "-- ERROR: Truststore '${path_truststoreFile}' does NOT exists." && errFound="true"
  if [ "${errFound}" == "false" ]; then
	  keytool -storepasswd -new "${pwd_new}" -storepass "${pwd_old}" -keystore "${path_truststoreFile}" 2>/dev/null
  else
    echo "-- ERROR: Something went wrong. See above logs for details."
    exit 1
  fi
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This functions creates a PKCS12 keystore from Certificate (.pem) and
# certificateKey (.pem)
#
# Parameters:
#  - ${certName}: The certificate alias
#  - ${certificate}: The .pem (base64 encoded) of the certificate public key
#  - ${certificateKey}: The .pem (base64 encoded)  of the certificate private key
#  - ${path_keystoreFile}: The path to the pkcs12 keystore file to be created
#  - ${pwd_keystore}: pkcs12 keystore password
# ----------------------------------------------------------------------------------
function createPKCS12fromCerts() {
  local certName=${1}
  local certificate=${2}
  local certificateKey=${3}
  local path_keystoreFile=${4}
  local pwd_keystore=${5}
  local errFound="false"
  echo "-- Creating PKCS12 file '${path_keystoreFile}'"
  if [ -z "${certName}" ] || [ -z "${certificate}" ] || [ -z "${certificateKey}" ] ||
     [ -z "${path_keystoreFile}" ] || [ -z "${pwd_keystore}" ]; then
    echo "-- ERROR: Either one or more of the below are empty:"
    echo "   > certName length is ${#certName}"
    echo "   > certificate length is ${#certificate}"
    echo "   > certificateKey length is ${#certificateKey}"
    echo "   > path_keystoreFile length is ${#path_keystoreFile}"
    echo "   > pwd_keystore length is ${#pwd_keystore}"
    errFound="true"
  else
    echo "${certificate}" | base64 --decode > /tmp/cert.pem
    echo "${certificateKey}" | base64 --decode > /tmp/certkey.pem
    openssl pkcs12 -export -name "${certName}" \
      -inkey /tmp/certkey.pem -in /tmp/cert.pem \
      -out "${path_keystoreFile}" -passout pass:"${pwd_keystore}"
    if [ -f "${path_keystoreFile}" ]; then
      echo "-- Created successfully"
      rm -f /tmp/cert.pem /tmp/certkey.pem
    else
      echo "-- ERROR: ${path_keystoreFile} NOT created."
      errFound="true"
    fi
  fi
  if [ "${errFound}" == "true" ]; then
    echo "-- See above logs for details on ERROR(s)"
    echo "   Exiting ...."
    exit 1
  fi
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This functions add a certificate (.pem) to the Java TrustStore
#
# Parameters:
#  - ${certName}: The certificate alias
#  - ${certificate}: The .pem (base64 encoded) of the certificate public key
#  - ${path_truststoreFile}: The path to the truststore file
#  - ${pwd_truststore}: Truststore password
# ----------------------------------------------------------------------------------
function importCertIntoTrustStore() {
  local errFound="false"
  local path_tmpCertToAdd="/tmp/certs.pem"
  local errFoundCount=0
  local certName=${1}
  local certificate=${2}
  local path_truststoreFile=${3}
  local pwd_truststore=${4}
  local pathTmp_log="/tmp/output.log"
  echo "-- Importing Certificate (${certName}) into TrustStore (${path_truststoreFile})"
  [ -z "${certName}" ] && echo "-- ERROR: The Certificate ALias provided is empty." && errFound="true"
  [ -z "${certificate}" ] && echo "-- ERROR: The Certificate provided is empty." && errFound="true"
  [ -z "${pwd_truststore}" ] && echo "-- ERROR: The current Password for Truststore provided is empty." && errFound="true"
  [ ! -f "${path_truststoreFile}" ] && echo "-- ERROR: Truststore '${path_truststoreFile}' was NOT found." && errFound="true"
  if [ "${errFound}" == "false" ]; then
    echo "${certificate}" | base64 --decode > "${path_tmpCertToAdd}"
    errFoundCount="$(keytool -delete -trustcacerts -keystore "${path_truststoreFile}" -alias "${certName}" -storepass "${pwd_truststore}" -noprompt 2>/dev/null | grep -i "error" | wc -l)"
    if [ "${errFoundCount}" -eq "0" ]; then
      echo "-- Certificate alias '${certName}' found and sucessfully removed"
    else
      echo "-- Certificate alias '${certName}' does not already exists"
    fi
    keytool -importcert -trustcacerts -file "${path_tmpCertToAdd}" -keystore "${path_truststoreFile}" -alias "${certName}" -storepass "${pwd_truststore}" -noprompt 2>/dev/null > "${pathTmp_log}"
    errFoundCount=$(cat "${pathTmp_log}" | grep -i "error" | wc -l)
    if [ "${errFoundCount}" -eq "0" ]; then
      echo "-- Imported certificate sucessfully"
      rm "${pathTmp_log}"
    else
      echo "-- ERROR: ${errFoundCount} Error found. Certificate (${certName}) NOT imported into '${path_truststoreFile}'"
      cat "${pathTmp_log}"
      exit 1
    fi
    rm -f "${path_tmpCertToAdd}"
  else
    echo "-- ERROR: See above logs for details on ERROR(s)"
    echo "   Exiting ...."
    exit 1
  fi
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This function setup the Truststore for a Forgerock component
#
# Parameters:
#  - ${1}: Truststore full path
#  - ${2}: Truststore password
#  - ${3}: certsCsv: Bash array in format "<cert>!<alias>,<cert>!<alias>"
# ----------------------------------------------------------------------------------
function addCertsToTruststore() {
  local path_truststore="${1}"
  local pwdTruststore="${2}"
  local certsCsv="${3}"
  local errFound="false"
  
  echo "Setting up Trustsotre"
  echo "---------------------"
  echo "Trustsotre: ${path_truststore}"
  echo ""
  if [ ! -f "${path_truststore}" ]; then
    echo "-- ERROR: '${path_truststore}' does not exists."
    errFound="true"
  fi
  if [ -z "${pwdTruststore}" ]; then
    echo "-- ERROR: Truststore password provided is empty."
    errFound="true"
  fi
  if [ -z "${certsCsv}" ] || [[ ${certsCsv} != *'!'* ]]; then
    echo "-- ERROR: Certificate details provided is empty or in incorrect format."
    echo "   Expected format is <cert>!<alias>,<cert>!<alias>"
    errFound="true"
  fi

  if [ "${errFound}" == "false" ]; then
    IFS=' ,' read -ra arrCertsCsv <<< "${certsCsv}"
    for certDetails in "${arrCertsCsv[@]}"
    do
      echo "[ Getting certificate details for below: ]"
      certificate=
      alias=
      IFS=' !' read -ra arrCertDetails <<< "${certDetails}"
      certificate=${arrCertDetails[0]}
      alias=${arrCertDetails[1]}
      echo "  > Alias: ${alias}"
      echo "  > Cert length: ${#certificate}"
      if [ -z "${certificate}" ]; then
        echo "-- WARN: Provided certificate for '${alias}' is empty. Skipping processing."
        echo ""
      else
        importCertIntoTrustStore "${alias}" "${certificate}" "${path_truststore}" "${pwdTruststore}"
      fi
    done
  fi
  if [ "${errFound}" == "true" ]; then
    echo "-- ERROR: Something went wrong. See above log. Exiting..."
    exit 1
  fi
}

# ---------------------------------------------------------
# Function to import a PKCS12(.p12) keystore into Keystore.
# THe p.12 is a combination of a public and privare cett.
#
# Parameters:
#  - ${1}: The certificate alias
#  - ${2}: The path to the source .p12 keystore
#  - ${3}: The path to the destination truststore file
#  - ${4}: Password for destination keystore
#  - ${5}: Password for key in destination keystore
#  - ${6}: Destination keystore type. E.g. JCEKS, PKCS!
# ----------------------------------------------------------
function importPKCS12IntoKeyStore() {
  local errFound="false"
  local certName=${1}
  local path_keystoreFile_source=${2}
  local path_keystoreFile_dest=${3}
  local pwd_keystore=${4}
  local pwd_keystoreKey=${5}
  local storeTyp=${6}
  local errFoundCount=0
  local pathTmp_log="/tmp/output.log"
  echo "-- Importing '${path_keystoreFile_source}' into Keystore '${path_keystoreFile_dest}'"
	[ -z "${certName}" ] && echo "-- ERROR: The Certificate ALias provided is empty." && errFound="true"
  [ -z "${pwd_keystoreKey}" ] && echo "-- ERROR: The Keystore Key Password provided is empty." && errFound="true"
  [ -z "${storeTyp}" ] && echo "-- ERROR: The Keystore type provided is empty." && errFound="true"
  [ -z "${pwd_keystore}" ] && echo "-- ERROR: The Keystore Password provided is empty." && errFound="true"
  [ ! -f "${path_keystoreFile_source}" ] && echo "-- ERROR: Source Keystore '${path_keystoreFile_source}' was NOT found." && errFound="true"
  if [ "${errFound}" == "false" ]; then
    keytool -importkeystore -alias "${certName}" \
      -deststorepass "${pwd_keystore}" -destkeypass "${pwd_keystoreKey}" -destkeystore ${path_keystoreFile_dest} \
      -srcstorepass "${pwd_keystore}" -srckeystore "${path_keystoreFile_source}" \
      -srcstoretype pkcs12 -storetype "${storeTyp}" 2>/dev/null
    if [ -f "${path_keystoreFile_dest}" ]; then
      errFoundCount=$(keytool -export -keystore "${path_keystoreFile_dest}" -alias "${certName}" -storepass "${pwd_keystore}" 2>/dev/null | grep "error" | wc -l)
      if (( errFoundCount == 0 )); then
        echo "-- Imported completed"
      else
        echo "-- ERROR: Alias (${aliasName}) NOT found in Keystore"
        echo "-- Exiting ..."
        exit 1
      fi
    else
      echo "-- ERROR: Keystore (${path_keystoreFile_dest}) NOT created."
      echo "-- Exiting ..."
      exit 1
    fi
  else
    echo "-- ERROR: See above logs for details on ERROR(s)"
    echo "   Exiting ...."
    exit 1
  fi
  echo "-- Done"
  echo ""
}

# ----------------------------------------------
# Function to create self-signed certificate
# ${1} : Certificate Name
# ${2} : Certificate Key Name
# ${3} : Cert save location
# -----------------------------------------------
# createSelfSignedCert () {
#   echo "> Entered createSelfSignedCert ()"
#   echo ""
#   if [ -z "${1}" ]
#   then
#     echo "-- {1} is Empty. This should be Certificate Name"
#     ${1}="certName"
#     echo "-- {1} Set to ${1}"
#     echo ""
#   fi
#
#   if [ -z "${2}" ]
#   then
#     echo "-- {3} is Empty. This should be Certificate save folder location"
#     ${3}="/tmp/certs"
#     echo "-- {3} Set to ${3}"
#     echo ""
#   fi
#
#   if [ -z "${3}" ]
#   then
#     echo "-- {4} is Empty. This should be Certificate CN (Common Name)"
#     echo "-- Exiting ..."
#     echo ""
#     exit
#   fi
#
#   certName=${1}
#   certSaveFolder=${2}
#   certCN=${3}
#
#   rm -rf ${certSaveFolder}
#   mkdir -p ${certSaveFolder}
# 	echo "--> Creating certificate" 
#   mkdir -p ${certSaveFolder}
#
# # Creating self signed cert details file
# cat << EOF >> ${certSaveFolder}/certdetails.txt
# [req]
# default_bits = 2048
# prompt = no
# default_md = sha256
# req_extensions = req_ext
# distinguished_name = dn
#
# [ dn ]
# C = UK
# ST = London
# L = London
# O = Midships
# OU = Midships
# emailAddress = admin@Midships.io
# CN = ${certCN}
#
# [ req_ext ]
# subjectAltName = @otherCNs
#
# [ otherCNs ]
# DNS.1 = ${certCN}
# DNS.2 = *.${certCN}
# DNS.3 = *.${certCN#*.}
# EOF
#
#   echo "---- Cert folder created at ${certSaveFolder}"
#   openssl req -newkey rsa:2048 -nodes -keyout "${certSaveFolder}/${certName}-key.pem" -x509 -days 365 -out "${certSaveFolder}/${certName}.pem" -config <( cat "${certSaveFolder}/certdetails.txt" )
# 	echo "-- Exiting function"
#   echo ""
# }

# -----------------------------------------------
# Function to generate random string
# ${1} : Encoding: E.g base64
# ${2} : String length
# -----------------------------------------------
generateRandomString(){
  len=${2:-30}
  rndstr=$(openssl rand -base64 ${len})
  echo "$rndstr"
}

# -----------------------------------------------
# Function to add secrets to Vault from json file
# ${1} : return_val
# ${2} : VAULT URL
# ${3} : VAULT TOKEN
# ${4} : secrets path in Vault
# ${5} : json file path with data
# -----------------------------------------------
addSecretsToVault(){
  echo "-- Adding secrets to VAULT section '${4}'"
	local secret_info=$(curl -sk --header 'X-Vault-Token: '${3} \
		--header "X-Vault-Namespace: admin" \
    --request POST --data @${5} \
    ${2}/v1/${4} | jq -r '.data.destroyed')
	if [ "${errFound}" == "false" ]; then
  	eval "${1}='true'"
	else
		eval "${1}='false'"
	fi
  echo "-- Done"
  echo ""
}

#-------------------------------------------------
# Function to delete All vesion of secrets from Vault
# ${1} : VAULT URL
# ${2} : VAULT TOKEN
# ${3} : secrets path in Vault
# ${4} : Name of Secrets Engine
# -----------------------------------------------
deleteSecretsFromVault_AllVersions(){
  echo "-- Deleting ${3}"
  curl \
    --header 'X-Vault-Token: '${2} \
		--header "X-Vault-Namespace: admin" \
    --request DELETE \
     "${1}/v1/${4}/metadata/${3}"
  echo "-- Done"
  echo ""
}

# -----------------------------------------------
# Function to delete All vesion of secrets from Vault
# ${1} : VAULT URL
# ${2} : VAULT TOKEN
# ${3} : secrets path in Vault
# ${4} : Name of Secrets Engine
# -----------------------------------------------
deleteSecretsFromVault_LatestVersion(){
  echo "-- Deleting ${3}"
  curl \
    --header 'X-Vault-Token: '${2} \
		--header "X-Vault-Namespace: admin" \
    --request DELETE \
    "${1}/v1/${4}/data/${3}"
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------
# This function adds a file to a specific location with provided string
#
# Parameters:
#  - ${1}: The full path of the file to create
#  - ${2}: the string content for the file
# ----------------------------------------------------------------------
function addSharedFile() {
  local sharedFolder=${1%/*}
  if [ ! -d "${sharedFolder}" ]; then
    echo "--ERROR: Directory '${sharedFolder}' does NOT exists."
  else
    if [ -f "${1}" ]; then
      echo "-- WARN: File '${1}' already exists."
    else
      while [ ! -f "${1}" ]; do
        echo "${2}" > "${1}"
        echo "-- Creating file '${1}' ..."
        sleep 1
      done
      if [ ! -f "${1}" ]; then
        echo "-- ERROR: '${1}' NOT found after creation"
      fi
    fi
  fi
  echo ""
}

# ----------------------------------------------------------------------
# This function deletes a file from a specific location
#
# Parameters:
#  - ${1}: The full path of the file to delete
# ----------------------------------------------------------------------
function removeSharedFile() {
  if [ -f "${1}" ]; then
    rm -f "${1}"
    echo "-- Removed file '${1}'"
  else
    echo "-- WARN: File '${1}' was NOT found."
  fi
  echo ""
}

# ----------------------------------------------------------------------------------
# This function checks if a Forgerock K8s pod is alive. It will wait for a
# predefined time until the server is alive before it exits.
#
# Parameters:
#  -s|--svc:
#    Kubernetes service URL or FQDN for pod. Format for statefulset pod service URL is
#    {hostname}.{service-name}.{POD_NAMESPACE}.svc.cluster.local
#  -t|--type: Server type. 'ds', 'am' or 'idm'
#  -c|--channel: Transfer Protocol E.g. 'http' or 'https'
#  -p|--port: TCP Port number. E.g. '8443'
#  -z|--resSuccessTotal: Number of successful responses required
#  -f|--frequeny: How often to check for the required response code
#  -y|--resCurrentSuccessCount: Current counter of successful responses
#  -i|--iterations: Number of times to check for successful response
#  -r|--resCodeExpected: Expected HTTP response code required. Default 200
# ----------------------------------------------------------------------------------
function checkServerIsAlive() {
  local svcURL=
  local srvType=
  local svcChannel="http"
  local svcPort="80"
  local successCountReq=1
  local successCountCurr=1
  local noOfChecks=48
  local responseCodeExpected="200"
  local srv_aliveCounter=1
  local checkFrequency=10
  local srv_aliveURL=
  local responseCodeActual=

  # Getting Parameters
  while [[ "$#" -gt 0 ]]
  do
    case ${1} in
      -s|--svc)
        local svcURL="${2}"
        ;;
      -t|--type)
        local srvType="${2}"
        ;;
      -c|--channel)
        local svcChannel="${2}"
        ;;
      -p|--port)
        local svcPort="${2}"
        ;;
      -z|--resSuccessTotal)
        if [ -n "${2}" ] && [ "${2}" -eq "${2}" ] 2>/dev/null; then
          local successCountReq="${2}"
        fi
        ;;
      -y|--resCurrentSuccessCount)
        if [ -n "${2}" ] && [ "${2}" -eq "${2}" ] 2>/dev/null; then
          local successCountCurr="${2}"
        fi
        ;;
      -i|--iterations)
        if [ -n "${2}" ] && [ "${2}" -eq "${2}" ] 2>/dev/null; then
          local noOfChecks="${2}"
        fi
        ;;
      -r|--resCodeExpected)
        if [ -n "${2}" ] && [ "${2}" -eq "${2}" ] 2>/dev/null; then
          local responseCodeExpected="${2}"
        fi
        ;;
      -f|--frequeny)
        if [ -n "${2}" ] && [ "${2}" -eq "${2}" ] 2>/dev/null; then
          local checkFrequency="${2}"
        fi
        ;;
      #
    esac
    shift
  done

  # Validating Parameters
  # ---------------------
  if [ "${svcChannel,,}" == "openssl" ]; then
    # Openssl server port check
    if [ -z "${svcURL}" ] || [ "${svcURL}" == "null" ] || \
      [ -z "${svcChannel}" ] || [ "${svcChannel}" == "null" ] || \
      [ -z "${svcPort}" ] || [ "${svcPort}" == "null" ] || \
      [ -z "${successCountReq}" ] || [ "${successCountReq}" == "null" ] || \
      [ -z "${successCountCurr}" ] || [ "${successCountCurr}" == "null" ] || \
      [ -z "${noOfChecks}" ] || [ "${noOfChecks}" == "null" ] || \
      [ -z "${responseCodeExpected}" ] || [ "${responseCodeExpected}" == "null" ]; then
      echo "-- ERROR: Ensure that none of the below parameters are Null or Empty for the 'checkServerIsAlive' function:"
      echo "   [svcURL] $svcURL"
      echo "   [svcChannel] $svcChannel"
      echo "   [svcPort] $svcPort"
      echo "   [successCountReq] $successCountReq"
      echo "   [successCountCurr] $successCountCurr"
      echo "   [noOfChecks] $noOfChecks"
      echo "   [checkFrequency] ${checkFrequency}"
      echo "   [responseCodeExpected] $responseCodeExpected"
      echo "-- Exiting ..."
      echo ""
      exit 1
    fi
    srv_aliveURL="${svcURL}:${svcPort}"
    responseCodeExpected=1
    echo "-- Checking if Port on Server (${srv_aliveURL}) is alive"
    echo "   DEFAULT Response Code expected is ${responseCodeExpected}"
  else
    # REST call server check
    if [ -z "${svcURL}" ] || [ "${svcURL}" == "null" ] || \
      [ -z "${srvType}" ] || [ "${srvType}" == "null" ] || \
      [ -z "${svcChannel}" ] || [ "${svcChannel}" == "null" ] || \
      [ -z "${svcPort}" ] || [ "${svcPort}" == "null" ] || \
      [ -z "${successCountReq}" ] || [ "${successCountReq}" == "null" ] || \
      [ -z "${successCountCurr}" ] || [ "${successCountCurr}" == "null" ] || \
      [ -z "${noOfChecks}" ] || [ "${noOfChecks}" == "null" ] || \
      [ -z "${checkFrequency}" ] || [ "${checkFrequency}" == "null" ] || \
      [ -z "${responseCodeExpected}" ] || [ "${responseCodeExpected}" == "null" ]; then
      echo "-- ERROR: Ensure that none of the below parameters are Null or Empty for the 'checkServerIsAlive' function:"
      echo "   [svcURL] $svcURL"
      echo "   [srvType] $srvType"
      echo "   [svcChannel] $svcChannel"
      echo "   [svcPort] $svcPort"
      echo "   [successCountReq] $successCountReq"
      echo "   [successCountCurr] $successCountCurr"
      echo "   [noOfChecks] $noOfChecks"
      echo "   [checkFrequency] ${checkFrequency}"
      echo "   [responseCodeExpected] $responseCodeExpected"
      echo "-- Exiting ..."
      echo ""
      exit 1
    fi

    if [ "${srvType}" == "am" ]; then
      srv_aliveURL="${svcChannel}://${svcURL}:${svcPort}/${AM_URI}/json/health/live"
    elif [ "${srvType}" == "ds" ]; then
      srv_aliveURL="${svcChannel}://${svcURL}:${svcPort}/alive"
    elif [ "${srvType}" == "idm" ]; then
      srv_aliveURL="'${svcChannel}://${svcURL}:${svcPort}/openidm/info/ping' --header 'X-OpenIDM-Username: anonymous' --header 'X-OpenIDM-Password: anonymous' --header 'Accept-API-Version: resource=1.0'"
    else
      srv_aliveURL="${svcURL}"
    fi

    echo "-- Checking if URL (${srv_aliveURL}) is alive"
    echo "   Response Code expected is ${responseCodeExpected}"
  fi

  # Executing checks
  # ----------------
  if [ "${successCountCurr}" -le "${successCountReq}" ]; then
    echo "   Checking for a successful response ${successCountCurr}/${successCountReq} time(s)"
    if [ "${successCountCurr}" -eq "${successCountReq}" ]; then
      successCountCurr=$((successCountCurr + 1))
    fi
  else
    echo "   Checking for a successful response ${successCountReq}/${successCountReq} time(s)"
  fi

  while [[ "${responseCodeActual}" != "${responseCodeExpected}" ]];
  do
    if [ "${svcChannel,,}" == "openssl" ]; then
      responseCodeActual=$(timeout 1 openssl s_client -connect "${srv_aliveURL}" <<< echo 2>&1 | grep -i CONNECTED | wc -l)
    else
      responseCodeActual=$(curl -sk -o /dev/null -w "%{http_code}" "${srv_aliveURL}")
      responseCodeActual=${responseCodeActual:0:3}
      if ([ "${responseCodeActual}" == "302" ] && [ "${responseCodeExpected}" == "200" ]) ||
        ([ "${responseCodeActual}" == "201" ] && [ "${responseCodeExpected}" == "200" ]); then
        echo -n "   > (${srv_aliveCounter}/${noOfChecks}) Returned ${responseCodeActual}. "
        echo -n "'${responseCodeActual}' is an acceptable response code. "
        responseCodeActual="200"        
      fi
    fi

    echo -n "   > (${srv_aliveCounter}/${noOfChecks}) Returned '${responseCodeActual}'. "

    if [ "${responseCodeActual}" != "${responseCodeExpected}" ]; then
      echo "Waiting ${checkFrequency} seconds ..."
      sleep ${checkFrequency}
    fi

    if [ ${srv_aliveCounter} == ${noOfChecks} ]; then
      secondsWaitedFor=$((checkFrequency * noOfChecks))
      echo ""
      echo "   > Waited for ${secondsWaitedFor} seconds and NO valid response"
      echo "     Exiting ..."
      exit 1
    fi
    srv_aliveCounter=$((srv_aliveCounter + 1))
  done
  echo "-- Server available"
  echo ""
  
  if [ "${successCountCurr}" -le "${successCountReq}" ]; then
    echo "-- Waiting 10 before next attempt"
    sleep 10
    successCountCurr=$((successCountCurr + 1))
    checkServerIsAlive --svc "${svcURL}" --type "${srvType}" --channel "${svcChannel}" --port "${svcPort}" --resCurrentSuccessCount ${successCountCurr} --resSuccessTotal ${successCountReq} --resCodeExpected ${responseCodeExpected}
  else
    if [ "${responseCodeActual}" != "${responseCodeExpected}" ]; then
      sleep ${checkFrequency}
    fi
  fi
}

# ----------------------------------------------------------------------------------
# This function schecks the current ulimit for the user and updates are required
# based on the component type
# Parameters:
#  - ${1} Component Type. Allowed values 'ds'
# ----------------------------------------------------------------------------------
function manageUlimit(){
  local uName="$(id -Grn)"
  local uLimit_openFiles_frsoft=65536
  local uLimit_openFiles_frhard=131072
  local uLimit_openFiles="$(ulimit -n)"
  local path_fileDescriptors="/etc/security/limits.conf"

  echo -e "-> [ ** Displaying User '${uName}' Limits ** ]\n"
  ulimit -a
  echo ""

  if [ "${1}" == "ds" ]; then
    echo "-- Checking maximum 'open files' alowed by user('${uName}') ..."
    echo "  > uLimit_openFiles is '${uLimit_openFiles}'"
    echo "  > ForgeRock recommended limit is '${uLimit_openFiles_fr}'"
    if [ "${uLimit_openFiles_frsoft}" -gt "${uLimit_openFiles}" ] || [ "${uLimit_openFiles}" != "unlimited" ]; then
      echo "-- User Limit is below the recommended threshold. Updating ..."
      echo "${uName} soft nofile ${uLimit_openFiles_frsoft}" >> "${path_fileDescriptors}"
      echo "${uName} hard nofile ${uLimit_openFiles_frhard}" >> "${path_fileDescriptors}"
      echo "-- Done"
    else
      echo "-- User Limit is within recommended threshold
      "
      echo "   Nothing needs to be updated"
      echo "-- Done"
    fi
  fi
}

# -------------------------------------------------------
# This function displays the ulimit for the provided user 
# -------------------------------------------------------
function showUlimits(){
  local uName="$(id -Grn)"
  echo "-> [ ** Displaying User '${uName}' Limits ** ]"
  ulimit -a
  echo ""
}

# ----------------------------------------------------------------------------------
# This function sets the below ulimits for the provided user ID a
# - soft nofile
# - hard nofile
# 
# Parameters:
#  - ${1} Component Type. Allowed values 'ds'
#  - ${1} User ID for ulimits to set
# ----------------------------------------------------------------------------------
function updateUlimits(){
  echo "-> Updating uLimits"
  local uName="${2}"
  local uLimit_openFiles_frsoft=65536
  local uLimit_openFiles_frhard=131072
  local uLimit_openFiles="$(ulimit -n)"
  local path_fileDescriptors="/etc/security/limits.conf"

  if [ -z "${2}" ]; then
    echo "-- uName is EMPTY. Setting to current user"
    uName="$(id -Grn)"
    echo "-- Current user is '${uName}'"
    if [ "${uName}" ==  "root" ]; then
      echo "-- ERROR: cannot set ulimit for '${uName}'. Please correct. Exiting ..."
      echo ""
      exit 1
    fi
    echo ""
  fi

  if [ "${1}" == "ds" ]; then
    if [ -f "${path_fileDescriptors}" ]; then
      echo "-- '${path_fileDescriptors}' found. Updating with below limits..."
      echo "  > ${uName} soft nofile ${uLimit_openFiles_frsoft}"
      echo "  > ${uName} hard nofile ${uLimit_openFiles_frhard}"
      echo "${uName} soft nofile ${uLimit_openFiles_frsoft}" >> "${path_fileDescriptors}"
      echo "${uName} hard nofile ${uLimit_openFiles_frhard}" >> "${path_fileDescriptors}"
      echo "-- Done"
    else
      echo "-- WARN: '${path_fileDescriptors}' NOT found."
      echo "         Please confirm how to set ulimit per user for your OS and update code as required"
    fi
  else
    echo "-- WARN: No valid component type ('${1}') provided."
    echo "   Allowed values are 'ds'"
    echo "   Doing nothing"
  fi
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This function replaces all bash variables in a file with the values held in the 
# Environment variables
# 
# Parameters:
#  - ${1} path to file containing varibales to be replaced/substituted
# ----------------------------------------------------------------------------------
function substituteEnvVars(){
  local path_fileToUpdate="${1}"
  local path_tmpFile="/tmp/.fileforupdate"
  echo "-- Updating Environment variables in '${path_fileToUpdate}'"
  cp --attributes-only --preserve "${path_fileToUpdate}" "${path_tmpFile}"
  cat "${path_fileToUpdate}" | envsubst "$(printf '${%s} ' $(env | cut -d'=' -f1))" > "${path_tmpFile}"
  mv "${path_tmpFile}" "${path_fileToUpdate}"
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This function returns the Kubernetes SVC URL from a ForgeRock Servers FQDN list
# 
# Parameters:
#  - ${1} Return Value
#  - ${2} ForgeRock Servers FQDNs csv
#  - ${3} Remove pod name. E.g. 'true' or 'false'. Default 'false'
# ----------------------------------------------------------------------------------
function getSvcUrlFromFqdnPortString(){
  local fqdnsPortsCsv="${2}"
  local removePodName="${3:-false}"
  local arr_fqdnsPorts=$(echo ${fqdnsPortsCsv} | tr "," "\n") # split csv on comma
  local fqdn=
  local svcUrl=
  for fqdnPort in ${arr_fqdnsPorts}; do
    fqdn=$(echo ${fqdnPort} | cut -d ":" -f1) # Getting fqdn only from <fqdn>:port
    [ "${removePodName}" == "true" ] && fqdn="${fqdn#*.}" # Removing pod-name from svc url. <pod-name>.<svc-name>.<ns>.svc.<cluster-domain>
    svcUrl="${fqdn}"
    echo "-- Service URL calcuated: '${svcUrl}'"
    break 1 # break out of for loop
  done
  eval "${1}='${svcUrl}'"
}

# ----------------------------------------------------------------------------------
# This function updates Environment variables with secrets placeholder with the 
# actual required secrets value
# Parameters:
#  - ${1} secretMode : Can be 'REST' or 'volume'
#  - ${2} IDM secretPath or URL
#  - ${3} secretToken 
#  - ${4} showValues : Can be 'true' or 'false' (defaut)
# ----------------------------------------------------------------------------------
function setEnvVarsWithSecerts(){
  local errFound="false"
  local path_envToSet="/tmp/.vars-to-set"
  local path_envToUnset="/tmp/.vars-to-unset"
  local reqPrefix="TEMP_"
  local secretDetails=
  local secretName=
  local secretVal=
  local envName=
  local envVal=
  local starText=
  local secretPath=
  local secretMode="${1}"
  local secretPath="${2}"
  local secretToken="${3}" # Only required for 'REST' Secret Mode
  local showValues="${4:-false}"
  echo "-- Updating Secrets placeholder '%{placeholder-name}' in Environment Variables"
  echo "   '*' means Secret was retrieved from another component"
  if [ "${secretMode}" == "volume" ] || [ "${secretMode}" == "REST" ]; then
    [ -f "${path_envToSet}" ] && rm -rf "${path_envToSet}"
    [ -f "${path_envToUnset}" ] && rm -rf "${path_envToUnset}"
    [ -z "${secretPath}" ] && echo "-- ERROR: Path to IDM Secret provided is empty" && errFound="true"
    if [ "${errFound}" == "false" ]; then
      env | while IFS= read -r envLine; do
        starText=""
        arrSecretDetails=
        envVal=${envLine#*=}
        envName=${envLine%%=*}
        secretDetails=$(echo "${envVal}" | grep -o '%{[\/a-zA-Z_.][[a-zA-Z_0-9\-\/!]*}') # Looking for %{secrets-name} or %{secrets-path!secrets-name} 
        secretDetails="${secretDetails//%\{/}" # Remove %{
        secretDetails="${secretDetails//\}/}" # Remove }

        IFS='!' read -ra arrSecretDetails <<< "${secretDetails}"
        if [ ${#arrSecretDetails[@]} -gt 1 ]; then
          secretPath="${arrSecretDetails[0]}"
          secretName="${arrSecretDetails[1]}"
          starText="*"
        else
          secretName="${secretDetails}"
          secretPath="${secretPath}"
          starText=""
        fi
        if [ -n "${secretName}" ]; then
          if [ -z "${starText}" ]; then
            echo "   > Processing '${envName}' ... "
          else
            echo -n "   > Processing ${starText}'${envName} (${secretPath})' ... "
          fi
          getSecret secretVal "${secretMode}" "${secretPath}" "${secretName}" "false" "${secretToken}"
          if [ -n "${secretVal}" ]; then
            export ${envName}="${secretVal}"
            echo "export ${envName}=\"${secretVal}\"" >> "${path_envToSet}"
            echo "${envName}" >> "${path_envToUnset}"
            [ "${showValues}" == "true" ] && echo -n " Value: '${secretVal}' ... "
            echo "Done"
          else
            echo "-- ERROR: Secret '${secretName}' NOT found or Empty"
            errFound="true"
          fi
        fi
      done
      if [ -f "${path_envToSet}" ]; then
        echo "-- Setting variables ..."
        source "${path_envToSet}"
        [ "${showValues}" == "true" ] && cat "${path_envToSet}"
        rm -rf "${path_envToSet}"
      fi
    fi
  else
    echo "-- ERROR: Provided Secret Mode '${secretMode}' is invalid. Expected 'volume' or 'Rest'."
    errFound="true"
  fi
  echo "-- Done"
  echo ""
  if [ "${errFound}" == "true" ]; then
    echo "-- ERROR: See above for more details. Exiting ..."
    exit 1
  fi
}

# ----------------------------------------------------------------------------------
# This function unsets Environment variables with Secrets data
# ----------------------------------------------------------------------------------
function unsetEnvVarsWithSecerts(){
  local errFound="false"
  local path_envToUnset="/tmp/.vars-to-unset"
  local secretName=
  local secretVal=
  local envName=
  local envVal=
  echo "-- Unsetting Env Vars with Secrets"
  if [ -f "${path_envToUnset}" ]; then
    cat "${path_envToUnset}" | while IFS= read -r envVar; do
      if [ -n "${envVar}" ]; then
        unset ${envVar}
        echo "   > Processed '${envVar}'"
      fi
    done
  else
    echo "-- INFO: No Secrets placeholders found in Environment variables. Skipping ..."
  fi
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This function add a secret entry to a new or exising keystore
#
# Parameters:
#  - ${1}: Keystore full path
#  - ${2}: Keystore password
#  - ${3}: Secret entry string
#  - ${4}: Certificate alias
#  - ${5}: Destination Keystore type. E.g. JCEKS, JKS, etc.
# ----------------------------------------------------------------------------------
function addSecretEntryToKeystore() {
  local path_keystoreFile="${1}"
  local pwdKeystore="${2}"
  local pwdKeystoreKey="${3}"
  local secretEntryStr="${4}"
  local alias="${5}"
  local keystoreType="${6}"
  local errFound="false"
  local path_tmpFolder="${path_tmpFolder:-/tmp/idm}"
  local errFoundCount=0

  echo "-> Adding secret entry to keystore:"
  echo "   Keystore: ${path_keystoreFile}"

  if [ ! -f "${path_keystoreFile}" ]; then
    echo "-- ERROR: '${path_keystoreFile}' does not exists."
    errFound="true"
  fi
  if [ -z "${pwdKeystore}" ]; then
    echo "-- ERROR: Keystore password provided is empty."
    errFound="true"
  fi
  if [ -z "${pwdKeystoreKey}" ]; then
    echo "-- ERROR: Keystore Key password provided is empty."
    errFound="true"
  fi
  if [ -z "${secretEntryStr}" ]; then
    echo "-- ERROR: Secret entry strin provided is empty."
    errFound="true"
  fi
  if [ -z "${alias}" ]; then
    echo "-- ERROR: Certificate alias provided is empty."
    errFound="true"
  fi
  if [ ! -d "${path_tmpFolder}" ]; then
    echo "-- WARN: '${path_tmpFolder}' does not exists, creating ..."
    mkdir -p "${path_tmpFolder}"
    echo "-- Done"
    echo ""
  fi
  if [ -z "${keystoreType}" ]; then
    echo "-- WARN: keystore type provided is empty. Setting to 'JCEKS'"
    keystoreType="JCEKS"
    echo "-- Done"
    echo ""
  fi
  
  if [ "${errFound}" == "false" ]; then
    echo "-- Adding entry ..."
    echo "${secretEntryStr}" | keytool -importpass -alias "${alias}" -keystore "${path_keystoreFile}" -storetype "${keystoreType}" -storepass "${pwdKeystore}" -keypass "${pwdKeystoreKey}" 2>/dev/null
    errFoundCount=$(keytool -list -alias "${alias}" -keystore "${path_keystoreFile}" -storetype "${keystoreType}" -storepass "${pwdKeystore}" 2>/dev/null | grep "does not exist" | wc -l)
    if (( errFoundCount == 0 )); then
      echo "-- Imported alias '${alias}' into '${path_keystoreFile}'"
      echo ""
    else
      echo "-- ERROR: Alias (${alias}) NOT found in Keystore. Exiting..."
      errFound="true"
    fi
  fi
  if [ "${errFound}" == "true" ]; then
    echo "-- ERROR: Something went wrong. See above log. Exiting..."
    exit 1
  fi
}

# ----------------------------------------------------------------------------------
# This function create a PKCS12 store from a public private key pair  and then add
# the resulting .p12 to a new or exising keystore
#
# Parameters:
#  - ${1}: Keystore full path
#  - ${2}: Keystore password
#  - ${3}: Keystore key password 
#  - ${4}: Public certificate string
#  - ${5}: Private certificate string
#  - ${6}: Certificate alias
#  - ${7}: Destination Keystore type. E.g. JCEKS, JKS, etc.
# ----------------------------------------------------------------------------------
function createPKCS12addToKeystore() {
  local path_keystoreFile="${1}"
  local pwdKeystore="${2}"
  local pwdKeystoreKey="${3}"
  local certificate="${4}"
  local certificateKey="${5}"
  local alias="${6}"
  local keystoreType="${7}"
  local errFound="false"
  local path_tmpFolder="${path_tmpFolder:-/tmp}"
  local path_pkcs12file="${path_tmpFolder}/${alias}.p12"
  
  echo "-> Adding key pair to keystore:"
  echo "   PKCS12 (to add): ${path_pkcs12file}"
  echo "   Keystore: ${path_keystoreFile}"
  echo ""
  if [ -z "${pwdKeystore}" ]; then
    echo "-- ERROR: Keystore password provided is empty."
    errFound="true"
  fi
  if [ -z "${pwdKeystoreKey}" ]; then
    echo "-- ERROR: Keystore Key password provided is empty."
    errFound="true"
  fi
  if [ -z "${certificate}" ]; then
    echo "-- ERROR: Certificate provided is empty."
    errFound="true"
  fi
  if [ -z "${certificateKey}" ]; then
    echo "-- ERROR: Certificate Key provided is empty."
    errFound="true"
  fi
  if [ -z "${alias}" ]; then
    echo "-- ERROR: Certificate alias provided is empty."
    errFound="true"
  fi
  if [ ! -d "${path_tmpFolder}" ]; then
    echo "-- WARN: '${path_tmpFolder}' does not exists, creating ..."
    mkdir -p "${path_tmpFolder}"
    echo "-- Done"
    echo ""
  fi
  if [ -z "${keystoreType}" ]; then
    echo "-- WARN: keystore type provided is empty. Setting to 'JCEKS'"
    keystoreType="JCEKS"
    echo "-- Done"
    echo ""
  fi
  
  if [ "${errFound}" == "false" ]; then
    createPKCS12fromCerts "${alias}" "${certificate}" "${certificateKey}" "${path_tmpFolder}/${alias}.p12" "${pwdKeystore}"
    if [ -f "${path_tmpFolder}/${alias}.p12" ]; then
      importPKCS12IntoKeyStore "${alias}" "${path_tmpFolder}/${alias}.p12" "${path_keystoreFile}" "${pwdKeystore}" "${pwdKeystoreKey}" "${keystoreType}"
    else
      echo "-- ERROR: ${path_tmpFolder}/${alias}.p12 NOT found."
      errFound="true"
    fi
  fi
  if [ "${errFound}" == "true" ]; then
    echo "-- ERROR: Something went wrong. See above log. Exiting..."
    exit 1
  fi
}

# ----------------------------------------------------------------------------------
# This function setup the Truststore and Keystore for a Forgerock component
#
# Parameters:
#  - ${1}: Secrets Mode: Allowed values 'REST' or 'volume'
#  - ${2}: Secret Client Token: access token for authenticating with your secrets manager.
#  - ${3}: Truststore full path
#  - ${4}: Truststore password
#  - ${5}: certsPaths: Bash array in format "ds_component1_secrets_path!cert_alias" "ds_component1_secrets_path!cert_alias"
#          For instance: "/opt/ds/secrets/ts!token-store" "/opt/ds/secrets/rs!repl-server"
#  - ${6}: certAlias: Alias provided for current DS component. Should match one of aliases in in certsPaths
#  - ${7}: Keystore full path: Full path to keystore file to be created
#  - ${8}: Keystore password: Password for Keystore to be created
# ----------------------------------------------------------------------------------
function setupTrustAndKeyStores() {
  local tmpSecretsMode="${1}"
  local secretClient_token="${2}"
  local path_truststore="${3}"
  local pwdTruststore="${4}"
  local certsPathsCsv="${5}"
  local certAlias="${6}"
  local path_keystoreFile="${7}"
  local pwdKeystore="${8}"
  local continueProcess=

  echo "Setting up Trustsotre and Keystore"
  echo "----------------------------------"
  echo "Current Server Cert Alias: ${certAlias}"

  changeTrustStorePassword "${path_truststore}" "changeit" "${pwdTruststore}"

  IFS=' ,' read -ra arrCertsPaths <<< "${certsPathsCsv}"
  for certPath in "${arrCertsPaths[@]}"
  do
    echo "[ Getting certificate details for below: ]"
    urlOrPath=
    continueProcess="true"
    alias=

    IFS=' !' read -ra pathDetails <<< "${certPath}"
    urlOrPath=${pathDetails[0]}
    alias=${pathDetails[1]}
    echo "  > Secret Path: ${urlOrPath}"
    echo "  > Alias: ${alias}"
    if [ ! -d "${urlOrPath}" ]; then
      echo ""
      echo "-- WARN: '${urlOrPath}' does NOT exists. Skipping processing."
      echo ""
      continueProcess="false"
    elif [ -n "${urlOrPath}" ] && [ "${urlOrPath}" != "null" ] && [ "${continueProcess,,}" == "true" ]; then
      getSecret certificate "${tmpSecretsMode}" "${urlOrPath}" "certificate" "${secretClient_token}"
      getSecret certificateKey "${tmpSecretsMode}" "${urlOrPath}" "certificateKey" "${secretClient_token}"
      if [ -z "${certificate}" ] || [ -z "${certificateKey}" ] || [ "${certificate}" == "null" ] || [ "${certificateKey}" == "null" ] || [ "${certificate}" == "" ] || [ "${certificateKey}" == "" ]; then
        echo "-- ERROR: Could not retrieve Cert and/or Key"
        exit 1
      else
        importCertIntoTrustStore "${alias}" "${certificate}" "${path_truststore}" "${pwdTruststore}"
        if [ "${alias}" == "${certAlias}" ]; then
          createPKCS12fromCerts "${alias}" "${certificate}" "${certificateKey}" "${path_keystoreFile}" "${pwdKeystore}"
        fi
      fi
    else
      echo "-- No valid path provided for alias ${alias}"
      echo ""
    fi
  done
}

# ----------------------------------------------------------------------------------
# This function lists any environment variables that are empty and sets a boolean
# Does not support En vars with multi-line values
#
# Parameters:
#  - ${1}: Variable with boolean string 'true' or 'false' confirming is empty ENV was found
# ----------------------------------------------------------------------------------
function showEmptyEnvVars() {
  local errFound="false"
  echo "-- Showing empty environment variable(s). INFO: Variable with multi-line values"
  echo "   are not supported. Recommended such values should be stored base64 encoded." 
  while IFS= read -r line; do
    value=${line#*=}
    name=${line%%=*}
    if [ -z "${value}" ] && [ -n "${name}" ] ; then
      echo "-- ERROR: '${name}' is empty."
      errFound="true"
    fi
  done <<< "$(env)"
  [ "${errFound}" == "true" ] && echo ""
  echo "-- Done"
  echo ""
  eval "${1}='${errFound}'"
}

# ----------------------------------------------------------------------------------
# This sources a shell script with logging
# Parameters:
#  - ${1}: Path to file to source
# ----------------------------------------------------------------------------------
function sourceFile() {
  local path_tmp01="${1}" 
  echo "-> Loading '${path_tmp01}'"
  if [ -f "${path_tmp01}" ]; then
    source "${path_tmp01}"
  else
    echo "-- ERROR: '${path_tmp01}' does not exists. Skipping..."
  fi
  echo "-- Done"
  echo ""  
}

# ----------------------------------------------------------------------------------
# This prints a message to the console in clolur
# Parameters:
#  - ${1}: Message string
#  - ${2}: Message Type: 'error', 'warn', 'info'
#  - ${3}: exitProcess after printing message: 'true' or 'false'. default s 'false'
# ----------------------------------------------------------------------------------
function showMessage() {
  local errMsg="${1}"
  local msgType="${2:-none}"
  local exitProcess="${3:-false}"
  local color_red='\033[0;31m'
  local color_orange='\033[0;33m'
  local color_lgray='\033[0;37m'
  local color_end='\033[0m'

  case "${msgType}" in
    "error")
      echo -e "-- ${color_red}ERROR${color_end}: ${errMsg}"
      echo "          "
      ;;
    "warn")
      echo -e "-- ${color_orange}WARN${color_end}: ${errMsg}"
      ;;
    "info")
      echo -e "-- ${color_lgray}INFO${color_end}: ${errMsg}"
      ;;
    *)
      echo -e "-- ${errMsg}"
      ;;
  esac
  [ "${exitProcess}" == "true" ] && exit 1
}

# ----------------------------------------------------------------------------------
# Updates the value of a variable in a file
# Parameters:
#  - ${1}: Path to file to update
#  - ${2}: Variable to update. for instalce: VAR_NAME=
#  - ${3}: variable value to set. For instance newval
#  - ${4}: Is file to update a Json? 'true' or 'false'
#  NOTE: This will yield VAR_NAME=newvalue
# ----------------------------------------------------------------------------------
function replaceVarValInfile() {
  local path_fileToUpdate="${1}"
  local strReplacePrefix="${2}"
  local strValueToSet="${3}"
  local fileIsJson="${4:-false}"
  local errFnd="false"
  local path_tmpFile01=
  local strReplace=
  local strFind=

  echo "-> Updating variable value:"
  echo "   File: '${path_fileToUpdate}'"
  echo "   Variable: '${strReplacePrefix}'"
  if [ -f "${path_fileToUpdate}" ]; then
    path_tmpFile01="${path_fileToUpdate}.updated"
    if [ "${fileIsJson}" == "false" ]; then
      cat "${path_fileToUpdate}" > "${path_tmpFile01}"
    elif [ "${fileIsJson}" == "true" ]; then
      cat "${path_fileToUpdate}" | jq . > "${path_tmpFile01}"
    else
      showMessage "Invalid fileIsJson value. Received '${fileIsJson}', expected 'true' or 'false'." "error" 
      errFnd="true"
    fi
    if [ "${errFnd}" == "false" ]; then
      strFind="$(grep -o "${strReplacePrefix}.*\b" "${path_tmpFile01}")"
      [ -z "${strFind}" ] && strFind="$(grep -o "${strReplacePrefix}" "${path_tmpFile01}")"
      if [ -n "${strFind}" ]; then
        strReplace="${strReplacePrefix}${strValueToSet}"
        echo "   > Updating from '${strFind}' to '${strReplace}'"
        sed -i "s+$strFind+$strReplace+g" "${path_fileToUpdate}"
      else
        showMessage "Variable string '${strReplacePrefix}' NOT found in file. Skipping ..." "warn"
      fi
      rm "${path_tmpFile01}"
    fi
  else
    showMessage "'${path_fileToUpdate}' NOT found. Skipping ..." "warn"
  fi
  echo "-- Done"
  echo ""
}
# ----------------------------------------------------------------------------------
# Function to convert a software version to Number. It can handle up to
# 5 levels of a version. For instance:
#  > 1.2.3.4.5 will become 001002003004005
#  > 1.2.3     will become 001002003000000
#  > 1         will become 001000000000000
#
# NOTE: dpkg --compare-versions can be used to achieve the same thing but only
#       works on debian systems out of the box. This function is a bash driven
#       solution that will work on all Unix OS. Example usage below:
#       if $(dpkg --compare-versions "7.1.2" "gt" "7.1.1"); then
#
# This code was referenced from:
# https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
# ----------------------------------------------------------------------------------
function ver { printf "%03d%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); }

function checkForBashError() {
  if [ "${1}" -ne 0 ]; then
      echo "-- ERROR: Something went wrong. See above logs. Returned '${1}'. Exiting ..."
      exit 1;
  fi
}

