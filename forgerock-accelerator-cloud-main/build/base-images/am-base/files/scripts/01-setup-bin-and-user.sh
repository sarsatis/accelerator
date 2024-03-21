#!/usr/bin/env bash
# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

# This file contains scripts to configure the ForgeRock Access Manager
# (AM) image required by the Midships ForgeRock Accelerator.

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
echo "[** START: Running as User '$(id -anu)' **]"
echo " "

source "${MIDSHIPS_SCRIPTS}/tomcat-shared-functions.sh"

echo "-> Creating required folders";
mkdir -p "${AM_HOME}/scripts";
mkdir -p "${path_tmpBin}";
echo "-- Done";
echo " ";

echo "-> Displaying key ENV Variables";
echo "-- CATALINA_HOME is ${CATALINA_HOME}"
echo "-- JAVA_HOME is ${JAVA_HOME}"
echo "-- JAVA_CACERTS is ${JAVA_CACERTS}"
echo "-- AM_HOME is ${AM_HOME}"
echo "-- VERSION_AM is ${VERSION_AM}"
echo "-- AM_URI is ${AM_URI}"
echo "-- AM_PATH_CONFIG is ${AM_PATH_CONFIG}"
echo "-- AM_PATH_CONFIG_BASE is ${AM_PATH_CONFIG_BASE}"
echo "-- Done";
echo " ";

if [ $(ver ${VERSION_AM}) -lt $(ver 7.2.0) ]; then
  echo "-- ERROR: This version of the Midships ForgeRock Cloud Acceleraotr only supports Access Manager v7.2+ for File Based Config (FBC)."
  echo "   Version of AM provided is '${VERSION_AM}'. Please contact our sales / support team to get a supported version without FBC."
  echo "   Exiting ..."
  echo " "
  exit 1
fi

installCloudClient "${artifactory_source,,}" "${path_tmp}";

if [ -n "${downloadPath_am}" ] && [ -n "${downloadPath_amster}" ] && [ -n "${path_tmp}" ]; then
  # DELETE AND/OR AMEND IF CONDITION(S) NOT REQUIRED AS REQUIRED
  echo "-- Verifying artifactory_source (${artifactory_source,,})"
  echo ""
  if [ "${artifactory_source,,}" == "gcp" ]; then
    echo "-> Downloading components from GCP";
    echo "-- Downloading AM (${downloadPath_am})";
    gsutil cp "${downloadPath_am}" "${path_tmpBin}/${AM_URI}.zip";
    echo "-- Downloading Amster (${downloadPath_amster})";
    gsutil cp "${downloadPath_amster}" "${path_tmpBin}/${filename_amster}";
    echo "-- Done"
    echo ""
  elif [ "${artifactory_source,,}" == "aws" ]; then
    echo "-> Downloading components from AWS";
    echo "-- Downloading AM (${downloadPath_am})";
    aws s3 cp "${downloadPath_am}" "${path_tmpBin}/${AM_URI}.zip";
    echo "-- Downloading Amster (${downloadPath_amster})";
    aws s3 cp "${downloadPath_amster}" "${path_tmpBin}/${filename_amster}";
    echo "-- Done"
    echo ""
  elif [ "${artifactory_source,,}" == "sftp" ]; then
    echo "-> Downloading components via REST";
    if [ -n "${artifactory_uname}" ] && [ -n "${artifactory_pword}" ]; then
      echo "-> Downloading AM (${downloadPath_am}) via REST";
      curl -k -u ${artifactory_uname}:${artifactory_pword} "${downloadPath_am}" -o "${path_tmpBin}/${filename_am}"
      echo "-- Done";
      echo " ";
      echo "-> Downloading Amster (${downloadPath_amster}) via REST";
      curl -k -u ${artifactory_uname}:${artifactory_pword} "${downloadPath_amster}" -o "${path_tmpBin}/${filename_amster}"
      echo "-- Done";
      echo " ";
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
  fi
else
  echo "-- ERROR: Missing required below parameters:"
  echo "   > downloadPath_am: ${downloadPath_am}"
  echo "   > downloadPath_amster: ${downloadPath_amster}"
  echo "   > path_tmp: ${path_tmp}"
  echo "   Exiting ..."
  exit 1
fi

removeCloudClient "${artifactory_source,,}" "${path_tmp}";

echo "-> Creating User and Group";
groupadd -g 10002 forgerock;
useradd -m -u 10002 -g 10002 -m -d "/home/am" am;
id am
echo "-- Done";
echo " ";

echo "-- Listing temp folder '${path_tmp}'"
ls -ltra "${path_tmp}"
echo "-- Done";
echo " ";
echo "[** END: Running as User '$(id -anu)' **]"