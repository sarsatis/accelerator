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

source "${MIDSHIPS_SCRIPTS}/midshipscore.sh"

echo "-> Checking key ENV Variables";
echo "-- IDM_HOME is ${IDM_HOME}"
echo "-- PROJECTS is ${PROJECTS}"
echo "-- artifactory_baseUrl is ${artifactory_baseUrl}"
echo "-- filename_idm is ${filename_idm}"
echo "-- path_tmp is ${path_tmp}"
echo "-- Done";
echo "";

echo "-> Creating required folders";
mkdir -p ${IDM_HOME}/scripts;
mkdir -p ${PROJECTS};
mkdir -p ${path_tmp};
echo "-- Done";
echo "";

installCloudClient "${artifactory_source,,}" "${path_tmp}";

# DELETE AND/OR AMEND IF CONDITION(S) NOT REQUIRED AS REQUIRED
if [ -n "${downloadPath_idm}" ] && [ -n "${filename_idm}" ] && [ -n "${path_tmp}" ]; then
  if [ "${artifactory_source,,}" = "gcp" ]; then
    echo "-> Downloading components from GCP storage bucket";
    gsutil cp "${downloadPath_idm}" "${path_tmp}/${filename_idm}";
    echo "-- Done";
    echo "";
  elif [ "${artifactory_source,,}" = "aws" ]; then
    echo "-> Downloading components from AWS storage bucket";
    aws s3 cp "${downloadPath_idm}" "${path_tmp}/${filename_idm}";
    echo "-- Done";
    echo "";
  elif [ "${artifactory_source,,}" = "sftp" ]; then
    echo "-> Downloading DS (${downloadPath_idm}) from ftp";
    echo curl -k -u "${artifactory_uname}:${artifactory_pword}" "${downloadPath_idm}" -o "${path_tmp}/${filename_idm}"
    if [ -n "${artifactory_uname}" ] && [ -n "${artifactory_pword}" ]; then
      curl -k -u "${artifactory_uname}:${artifactory_pword}" "${downloadPath_idm}" -o "${path_tmp}/${filename_idm}"
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
  echo "   > downloadPath_idm: ${downloadPath_idm}"
  echo "   > filename_idm: ${filename_idm}"
  echo "   > path_tmp: ${path_tmp}"
  echo "   Exiting ..."
  exit 1
fi

removeCloudClient "${artifactory_source,,}" "${path_tmp}";

echo "-> Creating User and Group";
groupadd -g 10002 forgerock;
useradd -m -u 10002 -g 10002 -m -d "/home/idm" idm;
id idm
echo "-- Done";
echo "";

echo "-> Extracting IDM";
unzip -q "${path_tmp}/${filename_idm}" -d "${IDM_HOME}"
cp -R "${IDM_HOME}/openidm/." "${IDM_HOME}"
rm -rf "${IDM_HOME}/openidm"
echo "-- Done";
echo "";

echo "-> Setting permission(s)";
chown -R idm:forgerock "${IDM_HOME}" "${MIDSHIPS_SCRIPTS}" "${JAVA_CACERTS}" "${path_tmp}"
chmod -R u=rwx,g=rx,o=r "${IDM_HOME}" "${JAVA_CACERTS}";
echo "-- Done";
echo "";

echo "-> Cleaning up";
rm -rf "${path_tmp}";
echo "-- Done";
echo "";
