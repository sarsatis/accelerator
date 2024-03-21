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

igInstalled="false"

echo "-> Creating required folders";
mkdir -p "${IG_HOME}/scripts" "${IG_INSTANCE_DIR}" "${DIR_SECRETSTORES}" "${DIR_KEYSTORES}" "${DIR_ROUTES}" "${path_tmp}";
echo "-- Done";
echo " ";

echo "-> Checking key ENV Variables";
echo "-- TOMCAT_HOME is ${TOMCAT_HOME}"
echo "-- JAVA_HOME is ${JAVA_HOME}"
echo "-- JAVA_CACERTS is ${JAVA_CACERTS}"
echo "-- IG_HOME is ${IG_HOME}"
echo "-- IG_HOME is ${DIR_KEYSTORES}"
echo "-- downloadPath_ig_war is ${downloadPath_ig_war}"
echo "--     filename_ig_war is ${filename_ig_war}"
echo "-- downloadPath_ig_zip is ${downloadPath_ig_zip}"
echo "--     filename_ig_zip is ${filename_ig_zip}"
echo "-- Done";
echo " ";

installCloudClient "${artifactory_source,,}" "${path_tmp}";

if ([ -n "${downloadPath_ig_war}" ] && [ -n "${filename_ig_war}" ]) || 
   ([ -n "${downloadPath_ig_zip}" ] && [ -n "${filename_ig_zip}" ]) && 
   [ -n "${path_tmp}" ]; then
  # DELETE AND/OR AMEND IF CONDITION(S) NOT REQUIRED AS REQUIRED
  echo "-- Verifying artifactory_source (${artifactory_source,,})"
  echo " "
  if [ "${artifactory_source,,}" == "gcp" ]; then
    echo "-> Downloading IG (${downloadPath_ig_war}) from GCP";
    gsutil cp ${downloadPath_ig_war} ${path_tmp}/${filename_ig_war};
    echo ""
    echo "-> Downloading IG (${downloadPath_ig_zip}) from GCP";
    gsutil cp ${downloadPath_ig_zip} ${path_tmp}/${filename_ig_zip};
    echo ""
  elif [ "${artifactory_source,,}" == "aws" ]; then
    echo "-> Downloading IG (${downloadPath_ig}) from AWS";
    aws s3 cp ${downloadPath_ig_war} ${path_tmp}/${filename_ig_war};
    echo ""
    echo "-> Downloading IG (${downloadPath_ig_zip}) from AWS";
    aws s3 cp ${downloadPath_ig_zip} ${path_tmp}/${filename_ig_zip};
    echo ""
  elif [ "${artifactory_source,,}" == "sftp" ]; then
    if [ -z "${artifactory_uname}" ] || [ -z "${artifactory_pword}" ]; then
      echo "-- ERROR: Download SKIPPED due to below missing parameters."
      echo "   > artifactory_uname: ${artifactory_uname}"
      echo "   > artifactory_pword length: ${#artifactory_pword}"
      echo "   Exiting ..."
      exit 1
    fi
    echo "-> Downloading IG (${downloadPath_ig_war}) from sFTP";
    curl -k -u ${artifactory_uname}:${artifactory_pword} "${downloadPath_ig_war}" -o "${path_tmp}/${filename_ig_war}"
    echo ""
    echo "-> Downloading IG (${downloadPath_ig_zip}) from sFTP";
    curl -k -u ${artifactory_uname}:${artifactory_pword} "${downloadPath_ig_zip}" -o "${path_tmp}/${filename_ig_zip}"
    echo ""
  else
    echo "-- ERROR: Invalid artifactory_source '${artifactory_source}'"
    echo "   Allowed values are 'gcp', 'aws', 'sftp'"
    echo "   Exiting ..."
  fi
  echo "-- Done";
  echo " ";
else
  echo "-- ERROR: Missing required below parameters:"
  echo "   > downloadPath_ig_war: ${downloadPath_ig_war}"
  echo "   >     filename_ig_war: ${filename_ig_war}"
  echo "   >            path_tmp: ${path_tmp}"
  echo "   -- Or --"
  echo "   > downloadPath_ig_zip: ${downloadPath_ig_zip}"
  echo "   >     filename_ig_zip: ${filename_ig_zip}"
  echo "   >            path_tmp: ${path_tmp}"
  echo "   Exiting ..."
  exit 1
fi

removeCloudClient "${artifactory_source,,}" "${path_tmp}";
echo " "

echo "-> Creating User and Group";
groupadd -g 10002 forgerock;
useradd -m -u 10002 -g 10002 -m -d "/home/ig" ig;
id ig
echo "-- Done";
echo " ";

echo "-> Installing Identity Gateway (IG) in Tomcat";
tmpPath="${path_tmp}/${filename_ig_war}"
if [ -f "${tmpPath}" ] && [ -d "${CATALINA_HOME}/webapps" ]; then
  rm -rf "${CATALINA_HOME}/webapps/ROOT.war"
  rm -rf "${CATALINA_HOME}/webapps/ROOT"
  mv "${tmpPath}" "${CATALINA_HOME}/webapps/ROOT.war";
  echo "-- Done";
  echo " ";
  igInstalled="true"
else
  echo "-- WARN: Either IG file (${tmpPath}) or folder (${CATALINA_HOME}/webapps) cannot be found. Skipping ..."
  igInstalled="false"
  echo ""
fi

echo "-> Installing Identity Gateway (IG) - Standalone";
tmpPath="${path_tmp}/${filename_ig_zip}"
if [ -f "${tmpPath}" ] && [ -d "${IG_HOME}" ]; then
  echo "-- Unzipping ..."
  unzip -q "${tmpPath}" -d "${IG_HOME}";
  tmpPath="${IG_HOME}/identity-gateway"
  if [ -d "${tmpPath}" ]; then
    echo "-- Setting up ..."
    mv ${tmpPath}/* ${IG_HOME}/
    rm -rf ${tmpPath}
    igInstalled="true"
  fi
  echo "-- Done";
  echo " ";
else
  echo "-- WARN: Either IG file (${tmpPath}) or folder (${CATALINA_HOME}/webapps) cannot be found. Skipping ..."
  igInstalled="false"
  echo ""
fi

echo "-> Setting permission(s)";
chown -R ig:forgerock "${IG_HOME}" "${TOMCAT_HOME}" "${MIDSHIPS_SCRIPTS}" "${JAVA_CACERTS}" "${path_tmp}"
echo "-- Done";
echo " ";

echo "-> Cleaning up";
rm -rf "${path_tmp}";
echo "-- Done";
echo " ";

if [ "${igInstalled}" == "false" ]; then
  echo "-- ERROR: Something went wrong. See above logs for details. Exiting ..."
  ecit 1
fi