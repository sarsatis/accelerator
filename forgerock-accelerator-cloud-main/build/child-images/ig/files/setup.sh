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

echo "-> Loading '${MIDSHIPS_SCRIPTS}/midshipscore.sh'";
source ${MIDSHIPS_SCRIPTS}/midshipscore.sh
echo "-- Done";
echo " ";

errorFound="false"

installCloudClient "${artifactory_source,,}" "${path_tmp}";

if [ -n "${downloadPath_jarsDir}" ] && [ -n "${path_tmp}" ]; then
  # DELETE AND/OR AMEND IF CONDITION(S) NOT REQUIRED AS REQUIRED
  echo "-- Verifying artifactory_source (${artifactory_source,,})"
  echo ""
  if [ "${artifactory_source,,}" == "gcp" ]; then
    echo "-> Downloading components from GCP";
    echo "-- Downloading AM Jars (${downloadPath_jars})";
    gsutil cp "${downloadPath_jars}" "${IG_HOME}/";
    echo "-- Done"
    echo ""
  elif [ "${artifactory_source,,}" == "aws" ]; then
    echo "-> Downloading components from AWS";
    echo "-- Downloading AM Jars (${downloadPath_jars})";
    aws s3 cp "${downloadPath_jars}" "${IG_HOME}/" --recursive --exclude "*" --include "*.jar";
    echo "-- Done"
    echo ""
  elif [ "${artifactory_source,,}" == "sftp" ]; then
    echo "-> Downloading components via REST";
    if [ -n "${artifactory_uname}" ] && [ -n "${artifactory_pword}" ]; then
      echo "-> Downloading AM Jars (${downloadPath_jarsDir}) via REST";
      for i in `curl -k -u ${artifactory_uname}:${artifactory_pword} "${downloadPath_jarsDir}" | awk '{print $9}'`; do
        echo "[ Getting ${i} ]"
        curl -k -u ${artifactory_uname}:${artifactory_pword} "${downloadPath_jarsDir}${i}" -o "${IG_HOME}/${i}";
        echo "-- Done";
        echo " ";
      done
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
  echo "   > downloadPath_jarsDir: ${downloadPath_jarsDir}"
  echo "   > path_tmp: ${path_tmp}"
  errorFound="true"
fi

removeCloudClient "${artifactory_source,,}" "${path_tmp}";

if [ ! -d "${path_tmp}" ]; then
  echo "-- WARN: '${path_tmp}' Does not exists. Creating ..."
  mkdir -p "${path_tmp}"
  if [ $? -ne 0 ]; then
    echo "-- ERROR: Something went wrong creating '${path_tmp}'. Exiting ..."
    exit 1
  fi
  echo "-- Done"
else
  echo "-- Listing '${path_tmp}'"
  ls -ltra "${path_tmp}"
fi
echo " "

if [ "${errorFound}" == "true" ]; then
  echo "-- ERROR: See above for more details. Exiting ..."
  exit 1
fi