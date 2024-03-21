#!/bin/bash
# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

# Script to be executed by ForgeRock Identity Gateway (IG) Kubernetes
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
echo "||               ForgeRock Identity Gateway (IG)               ||"
echo "================================================================"
echo "->                     HOSTNAME: ${HOSTNAME}"
echo "->                     ENV_TYPE: ${ENV_TYPE}"
echo "->                      IG_HOME: ${IG_HOME}"
echo "->                      IG_TYPE: ${IG_TYPE}"
echo "->                      IG_MODE: ${IG_MODE}"
echo "->                      SECRETS: ${SECRETS}"
echo "->                   CONFIGMAPS: ${CONFIGMAPS}"
echo "->                  IG_KEYSTORE: ${IG_KEYSTORE}"
echo "->                  CONFIG_BASE: ${CONFIG_BASE}"
echo "->                    LB_DOMAIN: ${LB_DOMAIN}"
echo "->                       IG_URI: ${IG_URI}"
echo "->                    NAMESPACE: ${NAMESPACE}"
echo "->                  TOMCAT_HOME: ${TOMCAT_HOME}"
echo "->                    JAVA_HOME: ${JAVA_HOME}"
echo "->                 JAVA_CACERTS: ${JAVA_CACERTS}"
echo "->                 SECRETS_MODE: ${SECRETS_MODE}"
echo "->              IG_INSTANCE_DIR: ${IG_INSTANCE_DIR}"
echo "->                DIR_KEYSTORES: ${DIR_KEYSTORES}"
echo "->                   DIR_CONFIG: ${DIR_CONFIG}"
echo "->                   DIR_ROUTES: ${DIR_ROUTES}"
echo "->                   CERT_ALIAS: ${CERT_ALIAS}"
if [ "${SECRETS_MODE,,}" != "volume" ]; then
echo "->      SECRETS_MANAGER_BASE_URL: ${SECRETS_MANAGER_BASE_URL}"
echo "->      SECRETS_MANAGER_PATH_IDM: ${SECRETS_MANAGER_PATH_IG}"
echo "->         SECRETS_MANAGER_TOKEN: ${SECRETS_MANAGER_TOKEN}" 
fi
echo "----------------------------------------------------------------"
echo ""
source "${MIDSHIPS_SCRIPTS}/tomcat-shared-functions.sh"
path_tmpFolder="/tmp/ig"

echo "-> Creating Temp Folder '${path_tmpFolder}'"
mkdir -p "${path_tmpFolder}"
echo "-- Done"
echo ""

# Local Variables
# ---------------
sharedFolder="/opt/shared"
path_sharedFile_ig="${sharedFolder}/ig_done"
path_igPlugins="${TOMCAT_HOME}/webapps/${IG_URI}/WEB-INF/lib/"
lbPrimaryUrl="https://${LB_DOMAIN}/${IG_URI}"
path_from=""
path_to=""
filename=""

echo "==============================================="
echo "Setting up a NEW Identity Gateway (IG) instance"
echo "-----------------------------------------------"
echo ""

echo "Setting up pre-requsite(s)"
echo "--------------------------"
echo "-> Creating directories"
mkdir -p "${path_tmpFolder}" "${DIR_CONFIG}"
rm -rf "${sharedFolder:?}/*"
echo "-- Done"
echo ""

setEnvVarsWithSecerts "${SECRETS_MODE}" "${SECRETS}" "${SECRETS_MANAGER_TOKEN}" # Must be ran before any Environment variable usage
    
if [ -z "${LB_DOMAIN}" ]; then
  echo "-- WARN: LB_DOMAIN is empty. Setting to localhost."
  export LB_DOMAIN=localhost
fi

showEmptyEnvVars errorFound

if [ "${errorFound}" == "false" ]; then
  echo "Importing configuration file(s)"
  echo "-------------------------------"
  path_from="${CONFIG_BASE}/config"
  path_to="${DIR_CONFIG}"
  echo "From: ${path_from}"
  echo "  To: ${path_to}"
  echo ""
  echo -e "[*.json]\n"  
  [ ! -d "${path_from}" ] && echo "-- WARN: Directory '${path_from}' NOT found. Skipping import."  
  for currFile in ${path_from}/*.json; do
    filePath="${path_to}/$(basename ${currFile})"
    if [[ "${currFile}" == *"${IG_TYPE}"* ]]; then
      echo "-> Processing config '${currFile}'"
      filePath="${filePath//-${IG_TYPE}/}"
      cp "${currFile}" "${filePath}"
      echo "-- File copied to '${filePath}'"
      substituteEnvVars "${filePath}"
    fi
  done
  echo "-- Done"
  echo ""

  echo "Importing IG Routes"
  echo "-------------------"
  path_from="${CONFIG_BASE}/routes"
  path_to="${DIR_ROUTES}"
  echo "From: ${path_from}"
  echo "  To: ${path_to}"
  [ ! -d "${path_from}" ] && echo "-- WARN: Directory '${path_from}' NOT found. Skipping import."  
  for currFile in ${path_from}/*.json; do
    filePath="${path_to}/$(basename ${currFile})"
    echo "-> Processing route '${currFile}'"
    cp "${currFile}" "${filePath}"
    echo "-- File copied to '${filePath}'"
    substituteEnvVars "${filePath}"
  done
  echo "-- Done"
  echo ""

  if [ "${errorFound}" == "false" ]; then
    echo "-> Java Experimental VM Settings"
    java -XX:+UseContainerSupport -XshowSettings:vm -version
    echo ""

    igTrustedCertsCsv="${SECRET_CERTIFICATE}!${CERT_ALIAS}"
    changeTrustStorePassword "${JAVA_CACERTS}" "changeit" "${SECRET_PASSWORD_TRUSTSTORE}"
    addCertsToTruststore "${JAVA_CACERTS}" "${SECRET_PASSWORD_TRUSTSTORE}" "${igTrustedCertsCsv}"
    createPKCS12fromCerts "${CERT_ALIAS}" "${SECRET_CERTIFICATE}" "${SECRET_CERTIFICATE_KEY}" "${IG_KEYSTORE}" "${SECRET_PASSWORD_KEYSTORE}"
  
    if [ "${IG_TYPE,,}" == "tomcat" ]; then
      path_tomcatServerXml="${CATALINA_HOME}/conf/server.xml"
      echo "-> Updating Tomcat Keystore in '${path_tomcatServerXml}'"
      path_tmp01="${CONFIG_BASE}/config/server.xml"
      if [ -f "${path_tomcatServerXml}" ]; then
        echo "-- Backing up xml..."
        cp -p "${path_tomcatServerXml}" "${path_tomcatServerXml}.bak"
        if [ -f "${path_tmp01}" ]; then
          echo "-- Copying Tomcat '${path_tmp01}' template to ${CATALINA_HOME}/conf"
          cp "${path_tmp01}" "${path_tomcatServerXml}"
          echo "-- Updating with keystore and Truststore information"
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

      echo "-> Setting Tomcat heap and perm settings"
      echo  "export JAVA_OPTS=\"${JAVA_OPTS}\"" > "${CATALINA_HOME}/bin/setenv.sh"
      echo "-- Done"
      echo ""

      if [ "$(ls -A ${IG_HOME} | grep -i \\.jar\$)" ]; then
        path_igPlugins="${CATALINA_HOME}/webapps/${IG_URI}/WEB-INF/lib/"
        echo "-> Deploying below IG plugins:"
        ls -A ${IG_HOME} | grep -i \\.jar\$
        echo " "
        echo "-- Moving to ${path_igPlugins}"
        mv -f ${IG_HOME}/*.jar ${path_igPlugins}
        echo "-- Done"
        echo " "
      fi
    elif [ "${IG_TYPE,,}" == "standalone" ]; then
      echo "-> Manage Trust and Key Stores secrets"
      echo "-- Applying Keystore secret(s)"
      echo -n "${SECRET_PASSWORD_KEYSTORE}" > "${DIR_SECRETSTORES}/keystore.pass"
      echo "-- Applying Truststore secret(s)"
      echo -n "${SECRET_PASSWORD_TRUSTSTORE}" > "${DIR_SECRETSTORES}/truststore.pass"
      echo "-- Done"
      echo ""

      if [ "$(ls -A ${IG_HOME} | grep -i \\.jar\$)" ]; then
        path_igPlugins="${IG_INSTANCE_DIR}/extra"
        echo "-> Deploying below IG plugins:"
        ls -A ${IG_HOME} | grep -i \\.jar\$
        echo " "
        echo "-- Moving to ${path_igPlugins}"
        mkdir -p "${path_igPlugins}"
        mv -f ${IG_HOME}/*.jar ${path_igPlugins}
        echo "-- Done"
        echo " "
      fi
    else
      echo "-- ERROR: Invalid IG_TYPE '${IG_TYPE}' provided. Accepeted values are 'tomcat' and 'standalone'."
      errorFound="true"
    fi
    
    if [ "${errorFound}" == "false" ]; then
      echo "-- INFO: Identity Gateway(IG) installation found."
      if [ "${IG_MODE^^}" == "DEVELOPMENT" ]; then
        echo "-- Studio URL is '${lbPrimaryUrl}/studio'"
      fi
      echo ""
      unsetEnvVarsWithSecerts

      echo "Starting IG instance"
      echo "--------------------"
      if [ "${IG_TYPE,,}" == "tomcat" ]; then
        echo "-- Starting Tomcat"
        manageTomcat "start"
      elif [ "${IG_TYPE,,}" == "standalone" ]; then
        echo "-- Starting Standalone IG"
        ${IG_HOME}/bin/start.sh "${IG_INSTANCE_DIR}"
      fi
    fi
  fi
fi
if [ "${errorFound}" == "true" ]; then
  echo "-- ERROR: Something went wrong installing Identity Gateway. See above logs for more details. Exiting ..."
  exit 1
fi