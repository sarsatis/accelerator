#!/usr/bin/env bash
# =====================================================================
# MIDSHIPS
# COPYRIGHT 2023

# This file contains scripts to configure the base Tomcat image
# required by the Midships ForgeRock Accelerator.

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
# ---------------------------------------------------------------------

echo "-> Loading '${MIDSHIPS_SCRIPTS}/midshipscore.sh'";
source "${MIDSHIPS_SCRIPTS}/midshipscore.sh"
echo "-- Done";
echo " ";

echo "-> Creating required folders";
mkdir -p ${CATALINA_HOME} ${path_tmp}
echo "-- Done";
echo "";

installCloudClient "${artifactory_source,,}" "${path_tmp}";

if [ -n "${downloadPath_tomcat}" ] && [ -n "${path_tmp}" ]; then
  # DELETE AND/OR AMEND IF CONDITION(S) NOT REQUIRED AS REQUIRED
  echo "-- Verifying artifactory_source (${artifactory_source,,})"
  echo ""
  if [ "${artifactory_source,,}" = "gcp" ]; then
    echo "-> Downloading Tomcat (${downloadPath_tomcat}) from GCP";
    gsutil cp "${downloadPath_tomcat}" "${path_tmp}/apache-tomcat-${tomcat_version}.zip";
  elif [ "${artifactory_source,,}" = "aws" ]; then
    echo "-> Downloading Tomcat (${downloadPath_tomcat}) from AWS";
    aws s3 cp "${downloadPath_tomcat}" "${path_tmp}/apache-tomcat-${tomcat_version}.zip";
  elif [ "${artifactory_source,,}" = "sftp" ]; then
    echo "-> Downloading Tomcat (${downloadPath_tomcat}) from FTP";
    if [ -n "${artifactory_uname}" ] && [ -n "${artifactory_pword}" ]; then
      curl -k -u ${artifactory_uname}:${artifactory_pword} "${downloadPath_tomcat}" -o "${path_tmp}/apache-tomcat-${tomcat_version}.zip"
    else
      echo "-- ERROR: Download SKIPPED due to below missing parameters."
      echo "   > artifactory_uname: ${artifactory_uname}"
      echo "   > artifactory_pword length: ${#artifactory_pword}"
      echo "   Exiting ..."
      exit 1
    fi
  else
    echo "-- ERROR: Invalid artifactory_source '${artifactory_source}'"
    echo "   Allowed values are 'gcp', 'aws', 'sftp'"
    echo "   Exiting ..."
    exit 1 
  fi
  echo "-- Done";
  echo "";
else
  echo "-- ERROR: Missing required below parameters:"
  echo "   > downloadPath_ds: ${downloadPath_tomcat}"
  echo "   > path_tmp: ${path_tmp}"
  echo "   Exiting ..."
  exit 1
fi

removeCloudClient "${artifactory_source,,}" "${path_tmp}";

echo "-> Installing Tomcat";
echo "-- TOMCAT_HOME is '${TOMCAT_HOME}'"
echo "-- Unpacking to ${TOMCAT_HOME}"
unzip -q "${path_tmp}/apache-tomcat-${tomcat_version}.zip" -d "${TOMCAT_HOME}";
ls -ltr ${TOMCAT_HOME}
echo "-- Done";
echo "";

echo "-> Verifying CATALINA_HOME '${CATALINA_HOME}'";
if [ -d "${CATALINA_HOME}" ]; then
  echo "CATALINA_HOME directory exists."
else
  echo "-- ERROR: CATALINA_HOME directory does NOT exists. Exiting ..."
  exit 1
fi
echo "-- Done";
echo "";

echo "-> Creating User and Group";
groupadd -g 10001 tomcat
useradd -g tomcat -m -d /home/tomcat tomcat -u 10001 -g 10001
echo "-- Done";
echo "";

echo "-> Setting permission(s)";
cd ${CATALINA_HOME};
chgrp -R tomcat conf;
chmod g+rwx conf;
chmod g+r conf/*;
chown -R tomcat logs/ temp/ webapps/ work/;
chgrp -R tomcat bin;
chgrp -R tomcat lib;
chmod g+rwx bin;
chmod g+r bin/*;
chmod a+x bin/*;
echo "-- Done";
echo "";

echo "-> Removing unwanted web apps";
rm -fr ${CATALINA_HOME}/webapps/manager
rm -fr ${CATALINA_HOME}/webapps/host-manager
rm -fr ${CATALINA_HOME}/webapps/examples
rm -fr ${CATALINA_HOME}/webapps/docs
rm -fr ${CATALINA_HOME}/webapps/ROOT
echo "-- Done";
echo "";

echo "-> Hiding Tomcat Version";
mkdir -p "${CATALINA_HOME}/lib/org/apache/catalina/util"
echo "server.info=\"Hidden Version\"" > "${CATALINA_HOME}/lib/org/apache/catalina/util/ServerInfo.properties"
echo "-- Done";
echo "";

echo "-> Cleaning up";
rm -rf ${path_tmp};
echo "-- Done";
echo "";
