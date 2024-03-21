#!/usr/bin/env bash
# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

# This file contains scripts to configure the base ForgeRock Directory
# Services (DS) image required by the Midships ForgeRock Accelerator.

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
source "${MIDSHIPS_SCRIPTS}/midshipscore.sh"
echo "-- Done";
echo " ";

echo "-> Creating required folders";
mkdir -p "${path_tmp}"
echo "-- Done";
echo "";

updateUlimits "ds" "ds"
installCloudClient "${artifactory_source,,}" "${path_tmp}";

if [ -n "${downloadPath_ds}" ] && [ -n "${path_tmp}" ] && [ -n "${filename_ds}" ]; then
  # DELETE AND/OR AMEND IF CONDITION(S) NOT REQUIRED AS REQUIRED
  echo "-- Verifying artifactory_source (${artifactory_source,,})"
  echo ""
  if [ "${artifactory_source,,}" == "gcp" ]; then
    echo "-> Downloading DS (${downloadPath_ds}) from GCP";
    gsutil cp ${downloadPath_ds} ${path_tmp}/${filename_ds};
  elif [ "${artifactory_source,,}" == "aws" ]; then
    echo "-> Downloading DS (${downloadPath_ds}) from AWS";
    aws s3 cp ${downloadPath_ds} ${path_tmp}/${filename_ds};
  elif [ "${artifactory_source,,}" == "sftp" ]; then
    echo "-> Downloading DS (${downloadPath_ds}) from sFTP";
    if [ -n "${artifactory_uname}" ] && [ -n "${artifactory_pword}" ]; then
      curl -k -u ${artifactory_uname}:${artifactory_pword} "${downloadPath_ds}" -o "${path_tmp}/${filename_ds}"
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
  echo "   > downloadPath_ds: ${downloadPath_ds}"
  echo "   > filename_ds: ${filename_ds}"
  echo "   > path_tmp: ${path_tmp}"
  echo "   Exiting ..."
  exit 1
fi

removeCloudClient "${artifactory_source,,}" "${path_tmp}";

echo "-> Creating User and Group";
groupadd -g 10002 forgerock;
useradd -m -u 10002 -g 10002 -m -d "/home/ds" ds;
id ds
echo "-- Done";
echo "";

echo "-> Creating required folders";
mkdir -p ${DS_APP} ${DS_INSTANCE} ${DS_SCRIPTS} ${path_tmp}
echo "-- Done";
echo "";

echo "-> Copying DS setup files";
if [ -f "${path_tmp}/${filename_ds}" ]; then
  unzip -q ${path_tmp}/${filename_ds} -d ${DS_HOME}
  if [ $? -ne 0 ]; then
    echo "-- ERROR: Unable to unzip file. Exiting ..."
    exit 1
  fi
  echo "-- Done";
  echo "";
else
  echo "-- ERROR: '${path_tmp}/${filename_ds}' NOT found. Exiting ..."
  exit 1
fi

echo "-> Backing up DS binary incase needed for upgrade later";
mv ${path_tmp}/${filename_ds} ${DS_HOME}/
if [ -f "${DS_HOME}/${filename_ds}" ]; then
  echo "-- Done";
  echo "";
else
  echo "-- ERROR: '${DS_HOME}/${filename_ds}' NOT found. Exiting ..."
  exit 1
fi

echo "-> Creating 'setupFiles' folder";
mv -f "${DS_HOME}/opendj" "${DS_HOME}/setupFiles"
echo "-- Files in ${DS_HOME}/setupFiles"
echo "-- Done";
echo "";

echo "-> Setting permission(s)";
chown -R ds:forgerock ${MIDSHIPS_SCRIPTS} ${DS_HOME} ${JAVA_CACERTS} ${path_tmp};
chmod -R u=rwx,g=rx,o=r ${DS_HOME}/setupFiles;
chmod -R u=rw,g=r,o=r "${JAVA_CACERTS}";
echo "-- Done";
echo "";

echo "-> Cleaning up";
rm -rf ${path_tmp};
echo "-- Done";
echo "";
