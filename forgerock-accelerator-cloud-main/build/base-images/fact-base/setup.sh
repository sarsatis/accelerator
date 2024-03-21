#!/usr/bin/env bash
# =====================================================================
# MIDSHIPS
# COPYRIGHT 2023

# This file contains scripts to configure the ForgeRock Identity Manager
# (IDM) Base Image required by the Midships ForgeRock Accelerator.

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

# Variables
path_amsterFolder="${TOOLS_HOME}/amster"

echo "-> Checking key ENV Variables";
echo "-- artifactory_baseUrl is ${artifactory_baseUrl}"
echo "-- artifactory_source is ${artifactory_source}"
echo "-- downloadPath_node is ${downloadPath_node}"
echo "-- path_tmp is ${path_tmp}"
echo "-- NODE_HOME is ${NODE_HOME}"
echo "-- Done";
echo " ";

echo "-> Creating required folders";
mkdir -p "${TOOLS_HOME}" "${path_amsterFolder}" "${path_tmp}";
echo "-- Done";
echo " ";

installCloudClient "${artifactory_source,,}" "${path_tmp}";

# DELETE AND/OR AMEND IF CONDITION(S) NOT REQUIRED AS REQUIRED
if [ -n "${downloadPath_node}" ] && [ -n "${filename_node}" ] && [ -n "${path_tmp}" ]; then
  if [ "${artifactory_source,,}" = "gcp" ]; then
    echo "-> Downloading components from GCP storage bucket";
    echo "-- Downloading '${downloadPath_node}' ..."
    gsutil cp "${downloadPath_node}" "${path_tmp}/${filename_node}";
    echo "-- Done";
    echo " ";
  elif [ "${artifactory_source,,}" = "aws" ]; then
    echo "-> Downloading components from AWS storage bucket";
    echo "-- Downloading '${downloadPath_node}' ..."
    aws s3 cp "${downloadPath_node}" "${path_tmp}/${filename_node}";
    echo "-- Done";
    echo " ";
  elif [ "${artifactory_source,,}" = "sftp" ]; then
    echo "-> Downloading DS required tools";
    if [ -n "${artifactory_uname}" ] && [ -n "${artifactory_pword}" ]; then
      echo "-- Downloading '${downloadPath_node}' ..."
      curl -k -u ${artifactory_uname}:${artifactory_pword} "${downloadPath_node}" -o "${path_tmp}/${filename_node}"
    else
      echo "-- ERROR: Download SKIPPED due to below missing parameters."
      echo "   > artifactory_uname: ${artifactory_uname}"
      echo "   > artifactory_pword length: ${#artifactory_pword}"
      echo "   Exiting ..."
      errorFound="true"
    fi
  else
    echo "-- ERROR: Invalid artifactory_source '${artifactory_source}'"
    echo "   Allowed values are 'gcp', 'aws', 'sftp'"
    echo "   Exiting ..."
  fi
else
  echo "-- ERROR: Missing required below parameters:"
  echo "   > downloadPath_node: ${downloadPath_node}"
  echo "   > filename_node: ${filename_node}"
  echo "   > path_tmp: ${path_tmp}"
  echo "   Exiting ..."
fi
removeCloudClient "${artifactory_source,,}" "${path_tmp}";

echo "-> Setting up Node JS";
echo "-- Unpacking ..."
mkdir -p "${NODE_HOME}"
tar -xJvf "${path_tmp}/${filename_node}" -C ${NODE_HOME}
echo "-- Verifying ..."
node -v
checkForBashError "$?"
echo "-- Done";
echo " ";

echo "-> Cleaning up";
rm -rf "${path_tmp}";
echo "-- Done";
echo " ";

if [ "${errorFound}" == "true" ]; then
  echo "-- ERROR: See above logs for details. Exiting ..."
  exit 1
fi
