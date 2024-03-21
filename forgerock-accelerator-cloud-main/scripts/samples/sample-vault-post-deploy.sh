#!/usr/bin/env bash
# =====================================================================
# MIDSHIPS
# COPYRIGHT 2018
# This file contains scripts to be executed after creation of MIDSHIPS
# SECRETS MANAGEMENT Kubernetes solution required by Midships Ready To
# Integrate (RTI) solution.
#
# NOTE: Don't check this file into source control with
#       any sensitive hard coded vaules.
# ---------------------------------------------------------------------

# ----------------------------------------------
# Function to create self-signed certificate
# ${1} : Certificate Name
# ${2} : Certificate Key Name
# ${3} : Cert save location
# -----------------------------------------------
createSelfSignedCert () {
  echo "> Entered createSelfSignedCert ()"
  echo ""
  if [ -z "${1}" ]
  then
    echo "-- {1} is Empty. This should be Certificate Name"
    ${1}="certName"
    echo "-- {1} Set to ${1}"
    echo ""
  fi

  if [ -z "${2}" ]
  then
    echo "-- {3} is Empty. This should be Certificate save folder location"
    ${3}="/tmp/certs"
    echo "-- {3} Set to ${3}"
    echo ""
  fi

  if [ -z "${3}" ]
  then
    echo "-- {4} is Empty. This should be Certificate CN (Common Name)"
    echo "-- Exiting ..."
    echo ""
    exit
  fi

  certName=${1}
  certSaveFolder=${2}
  certCN=${3}

  rm -rf ${certSaveFolder}
  mkdir -p ${certSaveFolder}
	echo "--> Creating certificate"
  mkdir -p ${certSaveFolder}

# Creating self signed cert details file
cat << EOF >> ${certSaveFolder}/certdetails.txt
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = UK
ST = London
L = London
O = Midships
OU = Midships
emailAddress = admin@Midships.io
CN = ${certCN}

[req_ext]
subjectAltName = @otherCNs

[otherCNs]
DNS.1 = ${certCN#*.}
DNS.2 = ${certCN}
DNS.3 = *.${certCN}
DNS.4 = *.${certCN#*.}
DNS.5 = *.eu-west-2.elb.amazonaws.com
EOF

  echo "---- Cert folder created at ${certSaveFolder}"
  # openssl req -new -newkey rsa:4096 -x509 -sha256 -days 365 -nodes -out ${certName}.pem -keyout ${certName}Key.pem -subj "/C=GB/ST=London/L=London/O=Midships/OU=IT Department/CN=midshipsCert.io"
  openssl req -newkey rsa:2048 -nodes -keyout "${certSaveFolder}/${certName}-key.pem" -x509 -days 365 -out "${certSaveFolder}/${certName}.pem" -extensions req_ext -config <( cat "${certSaveFolder}/certdetails.txt" )
  echo "-- Exiting function"
  echo ""
}

# -----------------------------------------------
# Function to generate random string
# ${1} : Encoding: E.g base64
# ${2} : String length
# -----------------------------------------------
generateRandomString(){
  rndstr=$(openssl rand -${1} ${2})
  echo $rndstr
}

# -----------------------------------------------
# Function to add secrets to Vault from json file
# ${1} : VAULT URL
# ${2} : VAULT TOKEN
# ${3} : secrets path in Vault
# ${4} : Name of Secrets Engine
# ${5} : json file path with data
# -----------------------------------------------
addSecretsToVault(){
  echo "-- Adding secrets to VAULT section '${1}/v1/${4}/data/${3}'"
  curl --header "X-Vault-Token: ${2}" \
    --header "X-Vault-Namespace: admin" \
    --request POST \
    --data @${5} \
    ${1}/v1/${4}/data/${3}
  echo " - Done"
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
  #curl \
  #  --header 'X-Vault-Token: '${SECRETS_MANAGER_TOKEN} \
  #  --request DELETE \
  #  ${VAULT_ADDR}/v1/${secretsEngineName}/data/${secretsPath}
  curl \
    --header "X-Vault-Token: ${2}" \
    --header "X-Vault-Namespace: admin" \
    --request DELETE \
     ${1}/v1/${4}/metadata/${3}
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
    --header "X-Vault-Token: ${2}" \
    --header "X-Vault-Namespace: admin" \
    --request DELETE \
    ${1}/v1/${4}/data/${3}
  echo "-- Done"
  echo ""
}

# ---------------
# Local variables
# ---------------
set -e
path="$(pwd)"
errorFound="false"
scriptAction=${1}
vaultURL="${2}"
export SECRETS_MANAGER_TOKEN=${3}
secretsEngineName=${4}
am_lbDomain="${5}"
envType=${6,,}
namespace=${7}
addClientNameToSecretsPath="${8}"
clientName="${9}"
genAppCert="${10}"
path_vaultKeysBackFolder=${HOME}/vault-masterkeys.txt
export VAULT_ADDR="${vaultURL}"

echo "***********************************************************"
echo "POST-DEPLOYMENT SETUP FOR VAULT SECRETS MANAGEMENT SOLUTION"
echo "***********************************************************"
echo "01.               scriptAction: ${scriptAction}"
echo "02.                   vaultURL: ${vaultURL}"
echo "03.                SECRETS_MANAGER_TOKEN: ${SECRETS_MANAGER_TOKEN}"
echo "04.          secretsEngineName: ${secretsEngineName}"
echo "05.                am_lbDomain: ${am_lbDomain}"
echo "06.                    envType: ${envType}"
echo "07.                  namespace: ${namespace}"
echo "08. addClientNameToSecretsPath: ${addClientNameToSecretsPath}"
echo "09.                 clientName: ${clientName}"
echo "10.                 genAppCert: ${genAppCert}"
echo "***********************************************************"

echo "------------------------"
echo "Checking input variables"
echo "------------------------"
echo ""

if [ -z "${1}" ]; then
  echo "-> {1} is EMPTY."
  echo "-- Please set SCRIPT ACTION to 'init', 'add', or 'delete'."
  echo ""
  errorFound="true"
fi

if [ -z "${2}" ]; then
  echo "-> {2} is EMPTY."
  echo "-- Please set to the URL for the VAULT server. E.g http://10.10.10.10:8200"
  echo ""
  errorFound="true"
fi

if [ -z "${3}" ]; then
  echo "-> {3} is EMPTY."
  echo "-- Please set to the SECRETS_MANAGER_TOKEN for access the secrets path on the VAULT server. E.g x.MO2n7SHKXe15H4uLwRq6tsCN"
  echo ""
  errorFound="true"
fi

if [ -z "${4}" ]; then
  echo "-> {4} is EMPTY."
  echo "-- Please set the NAME of the SECRET-ENGINE this deployment if for. E.g. 'client01."
  echo ""
  errorFound="true"
fi

if [ -z "${5}" ]; then
  echo "-> {5} is EMPTY."
  echo "-- Please set the ForgeRock Access Manager (AM) LOAD BALANCER URL. E.g. 'am.d2portal.co.uk'."
  echo ""
  errorFound="true"
fi

if [ -z "${6}" ]; then
  echo "-> {6} is EMPTY."
  echo "-- Setting the ENVIRONMENT TYPE for the secrets to 'sit."
  echo ""
  envType="sit"
fi

if [ -z "${7}" ]; then
  echo "-> {7} is EMPTY."
  echo "-- Setting NAMESPACE the forgerock pod will be running under to 'default'."
  echo ""
  namespace="default"
fi

if [ -z "${8}" ]; then
  echo "-> {8} is EMPTY."
  echo "-- Setting 'addClientNameToSecretsPath' to 'yes'."
  addClientNameToSecretsPath="yes"
  echo ""
fi

if [ -z "${9}" ]; then
  echo "-> {9} - 'CLIENT_NAME' is EMPTY."
  echo ""
fi

if [ -z "${10}" ]; then
  echo "-> {10} - 'GENERATE APP CERT' is EMPTY. Will be set to 'no' by default"
  genAppCert="no"
  echo ""
fi

echo "-- Done"
echo ""

if [ "${errorFound}" == "false" ]; then

  case "${scriptAction}" in
    "init")
      echo "------------------"
      echo "Initializing Vault"
      echo "------------------"
      echo ""
      curl --request PUT --data '{
             "secret_shares": 5,
             "secret_threshold": 3
           }' \
      ${VAULT_ADDR}/v1/sys/init > ${path_vaultKeysBackFolder}
      cat ${path_vaultKeysBackFolder}
      ;;
    "create-se")
      echo "-------------------------"
      echo "Create KV2 Secrets Engine"
      echo "-------------------------"
      echo ""
      echo "-> Creating secrets engine ..."
      secret_info=$(curl -s --request POST \
          --header "X-Vault-Token: ${SECRETS_MANAGER_TOKEN}" \
          --header "X-Vault-Namespace: admin" \
          --data '{ "type": "kv", "description": "", "options": { "version": "2" } }' \
          ${VAULT_ADDR}/v1/sys/mounts/${secretsEngineName})

      if [ -z "${secret_info}" ] || [ "${secret_info}" == "null" ]; then
        echo "-- Secrets engine '${secretsEngineName}' created successfully."
        echo ""
      else
        echo "--Error ruturned during secrets creation."
        echo ${secret_info}
        echo ""
      fi

      echo "-> Setting secrets engine properties"
      curl \
       --header "X-Vault-Token: ${SECRETS_MANAGER_TOKEN}" \
       --header "X-Vault-Namespace: admin" \
       --request POST \
       --data '{
         "max_versions": 10,
         "cas_required": false,
         "delete_version_after": "0s"
       }' \
       ${VAULT_ADDR}/v1/${secretsEngineName}/config
      echo "-- Done"
      echo ""
      ;;
    "add-secrets")
      echo "-----------------------"
      echo "Adding Secrets to Vault"
      echo "-----------------------"
      path_tmpFile=./tmp.json
      echo "-> Loading ${secretsEngineName} details"
      echo ""
      for filename in hashicorp-vault/*.json; do
          echo "-> Processing ${filename}"
          [ -e "${filename}" ] || continue
          rootSection=${filename##*/}
          rootSection=${rootSection%.*}

          if [ "${genAppCert}" == "yes" ]; then
            echo "-- Generating self-signed certs"
            if [ "${rootSection}" == "access-manager" ]; then
              createSelfSignedCert "${rootSection}" "/tmp/${rootSection}" "${am_lbDomain}"
            elif [ "${rootSection}" == "config-store" ] ||  [ "${rootSection}" == "token-store" ] || [ "${rootSection}" == "user-store" ] || [ "${rootSection}" == "repl-server" ]; then
              echo "-- Generating CERT"
              createSelfSignedCert "${rootSection}" "/tmp/${rootSection}" "*.forgerock-${rootSection}.${namespace}.svc.cluster.local"
            else
              createSelfSignedCert "${rootSection}" "/tmp/${rootSection}" "forgerock-${rootSection}.${namespace}.svc.cluster.local"
            fi
            cert=$(cat /tmp/${rootSection}/${rootSection}.pem | base64 | sed 's/ //g' | sed -z 's/\n//g')
            certkey=$(cat /tmp/${rootSection}/${rootSection}-key.pem | base64 | sed 's/ //g' | sed -z 's/\n//g')

            echo "-- Updating the required json file with encoded certs"
            cat ./${filename} | jq ".certificate=\"${cert}\"" | jq ".certificateKey=\"${certkey}\"" > ${path_tmpFile}
            mv -f ${path_tmpFile} ./${filename}
          fi

          if [ ${addClientNameToSecretsPath,,} == "yes" ]; then
            secretsPath="${clientName}/forgerock/${envType}/${rootSection}"
          else
            if [ ! -z "${clientName}" ] && [ "${clientName}" != "null" ]; then
              secretsPath="${clientName}/forgerock/${envType}/${rootSection}"
            else
              secretsPath="${envType}/${rootSection}"
            fi
          fi

          #Adding data key to json for Vault REST call
          secretsContent=$(echo "{}" | jq -n --slurpfile filecontents ${filename} '.data=$filecontents[0]')
          echo ${secretsContent} > ${path_tmpFile}
          addSecretsToVault "${VAULT_ADDR}" "${SECRETS_MANAGER_TOKEN}" "${secretsPath}" "${secretsEngineName}" "${path_tmpFile}"
          rm -f "${path_tmpFile}"
      done
      ;;
    "del-secrets")
      # Delete all secrets in engine
      for filename in client-config/*.json; do

        echo "-> Processing ${filename}";
        [ -e "${filename}" ] || continue
        rootSection=${filename##*/}
        rootSection=${rootSection%.*}

        if [ ! -z "${clientName}" ] && [ "${clientName}" != "null" ]; then
          secretsPath="${clientName}/forgerock/${envType}/${rootSection}"
        else
          secretsPath="${envType}/${rootSection}"
        fi

        deleteSecretsFromVault_AllVersions "${VAULT_ADDR}" "${SECRETS_MANAGER_TOKEN}" "${secretsPath}" "${secretsEngineName}"
      done
      ;;
    *)
      echo "No option provided."
      exit 1
  esac
fi
