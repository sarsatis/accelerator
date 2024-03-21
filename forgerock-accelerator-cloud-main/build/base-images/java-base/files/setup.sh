#!/usr/bin/env bash
# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

# This file contains scripts to configure the base Java image required
# by the Midships ForgeRock Accelerator solution.

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
echo "[ START: Running as User '$(id -anu)' ]"
echo " "

echo "-> Sourcing ${MIDSHIPS_SCRIPTS}/midshipscore.sh";
source "${MIDSHIPS_SCRIPTS}/midshipscore.sh"
echo "-- Done";
echo "";

echo "-> Setting key variable(s)";
errorFound="false"
echo "-- Done";
echo "";

echo "-> Creating required folders";
mkdir -p ${MIDSHIPS_SCRIPTS} ${path_tmp} ${JVM_PATH}
echo "-- Done";
echo "";

echo "-> Key Variables";
echo "PATH is ${PATH}"
echo "JVM_PATH is ${JVM_PATH}"
echo "JAVA_HOME is ${JAVA_HOME}"
echo "-- Done";
echo "";

showUlimits

echo "-> Updating all installed packages on OS";
apt-get -y update
echo "-- Done";
echo "";

echo "-> Installing required tools";
# Package 'gettext-base' is used for 'envsubst'.
# Package 'procps' is used for 'ps' to get process IDs (E.g. in Tomcat base Image)
# Package 'iputils-ping' for 'ping'. Allows ping package for all pods. Can be removed if a 'nettools' pod can be deployed when required.
# App other packages are self-explanatory
apt-get -y install tar xz-utils openssl curl binutils unzip jq sed iputils-ping procps gettext-base;
echo "-- Done";
echo "";

echo "-> Cleaning packages on OS";
apt-get clean
#rm -r /var/lib/apt/lists /var/cache/apt/archives
echo "-- Done";
echo "";

echo "-> Making copied scripts executable";
chmod 751 ${MIDSHIPS_SCRIPTS}/*.sh ${path_tmp}/*.sh;
echo "-- Done";
echo "";

installCloudClient "${artifactory_source,,}" "${path_tmp}";

if [ -n "${downloadPath_jdk}" ] && [ -n "${path_tmp}" ] && [ -n "${filename_jdk}" ]; then
  # DELETE AND/OR AMEND IF CONDITION(S) NOT REQUIRED AS REQUIRED
  echo "-- Verifying artifactory_source (${artifactory_source,,})"
  echo ""
  if [ "${artifactory_source,,}" == "gcp" ]; then
    echo "-> Downloading JDK (${downloadPath_jdk}) from GCP";
    gsutil cp "${downloadPath_jdk}" "${path_tmp}/${filename_jdk}";
  elif [ "${artifactory_source,,}" == "aws" ]; then
    echo "-> Downloading JDK (${downloadPath_jdk}) from AWS";
    aws s3 cp "${downloadPath_jdk}" "${path_tmp}/${filename_jdk}";
  elif [ "${artifactory_source,,}" == "sftp" ]; then
    echo "-> Downloading JDK (${downloadPath_jdk}) from FTP";
    if [ -n "${artifactory_uname}" ] && [ -n "${artifactory_pword}" ]; then
      curl -k -u ${artifactory_uname}:${artifactory_pword} "${downloadPath_jdk}" -o "${path_tmp}/${filename_jdk}"
    else
      echo "-- ERROR: Download SKIPPED due to below missing parameters."
      echo "   > artifactory_uname: ${artifactory_uname}"
      echo "   > artifactory_pword length: ${#artifactory_pword}"
      errorFound="true"
    fi
  else
    echo "-- ERROR: Invalid artifactory_source '${artifactory_source}'"
    echo "   Allowed values are 'gcp', 'aws', 'sftp'"
    errorFound="true"
  fi
  echo "-- Done";
  echo "";
else
  echo "-- ERROR: Missing required below parameters:"
  echo "   > downloadPath_jdk: ${downloadPath_jdk}"
  echo "   > filename_jdk: ${filename_jdk}"
  echo "   > path_tmp: ${path_tmp}"
  errorFound="true"
fi

removeCloudClient "${artifactory_source,,}" "${path_tmp}";

if [ "${errorFound}" == "false" ]; then
  echo "-> Installing Java to '${JVM_PATH}'";
  path_tmp01="${path_tmp}/${filename_jdk}"
  if [ -f "${path_tmp01}" ] && [ -d "${JVM_PATH}" ]; then
    tar -xf "${path_tmp01}" -C "${JVM_PATH}/"
    ls -ltra "${JVM_PATH}"
    echo "-- Done";
    echo " ";
  else
    echo "-- ERROR: Either JDK file '${path_tmp01}' or folder '${JVM_PATH}' cannot be found."
    errorFound="true"
  fi

  if [ "${errorFound}" == "false" ]; then
    echo "-> Checking Java";
    echo "-- JAVA_HOME is set to ${JAVA_HOME}";
    java -version;
    checkForBashError "$?"
    echo "-- Done";
    echo ""

    if (( ${JAVA_VERSION_MAJOR} <= 8 )); then
      echo "-> Removing vulnerable jetty-server (v8.1.14) to resolve CVE-2017-7657";
      find  ${JAVA_HOME}/lib/missioncontrol/plugins/ -name 'org.eclipse.jetty.*' -exec rm {} \;
      echo "-- Done";
      echo "";
    fi

    echo "-> Creating cacerts with single 'sample' cert";
    alias="sample"
    storepass="changeit"
    echo "-- Backing up '${JAVA_CACERTS}' to '${JAVA_CACERTS}.bak'"
    mv "${JAVA_CACERTS}" "${JAVA_CACERTS}.bak"
    echo "-- Creating new cacerts with single entry";
    keytool -genkey -alias "${alias}" -keyalg RSA -storetype JKS -keypass "${storepass}" -storepass "${storepass}" \
      -keystore "${JAVA_CACERTS}" -dname "CN=test.sample.com, OU=sample, O=Company, L=City, ST=State, C=CA"
    checkForBashError "$?"
    echo "-- Done";
    echo ""
  fi
fi

if [ "${errorFound}" == "true" ]; then
  echo "-- ERROR:  Kindly see above log for details on erros. Exiting ..."
  exit 1
fi

echo "-> Cleaning up";
rm -rf ${path_tmp};
echo "-- Done";
echo "";

echo "[ END: Running as User '$(id -anu)' ]"
exit 0