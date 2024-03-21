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

echo "-> Loading '${MIDSHIPS_SCRIPTS}/tomcat-shared-functions.sh'";
source "${MIDSHIPS_SCRIPTS}/tomcat-shared-functions.sh"
echo "-- Done";
echo " ";

errorFound="false"

installCloudClient "${artifactory_source,,}" "${path_tmp}";

if [ -n "${downloadPath_jar}" ] && [ -n "${path_tmp}" ]; then
  # DELETE AND/OR AMEND IF CONDITION(S) NOT REQUIRED AS REQUIRED
  echo "-- Verifying artifactory_source (${artifactory_source,,})"
  echo ""
  if [ "${artifactory_source,,}" == "gcp" ]; then
    echo "-> Downloading components from GCP";
    echo "-- Downloading AM .jar file (${downloadPath_jar})";
    gsutil cp "${downloadPath_jar}" ${AM_HOME}/$(basename "${jarPath}");
    echo "-- Done"
    echo ""
  elif [ "${artifactory_source,,}" == "aws" ]; then
    echo "-> Downloading components from AWS";
    echo "-- Downloading AM .jar file (${downloadPath_jar})";
    aws s3 cp "${downloadPath_jar}" ${AM_HOME}/$(basename "${jarPath}");
    echo "-- Done"
    echo ""
  elif [ "${artifactory_source,,}" == "sftp" ]; then
    echo "-> Downloading components via REST";
    if [ -n "${artifactory_uname}" ] && [ -n "${artifactory_pword}" ]; then
      arr_jarPaths=(
        "${downloadPath_jar}"
      )
      for jarPath in "${arr_jarPaths[@]}"; do
        echo "-> Downloading AM .jar file (${jarPath}) via REST";
        curl -k -u ${artifactory_uname}:${artifactory_pword} "${jarPath}" -o ${AM_HOME}/$(basename "${jarPath}");
      done
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
else
  if [ -z "${path_tmp}" ] && [ -n "${downloadPath_jar}" ]; then
    echo "-- ERROR: Missing required below parameter(s):"
    echo "   > downloadPath_jar: ${downloadPath_jar}"
    echo "   > path_tmp: ${path_tmp}"
    echo "   Exiting ..."
    exit 1
  elif [ -n "${path_tmp}" ] && [ -z "${downloadPath_jar}" ]; then
    echo "-- INFO: No .jar provided for download skipping ..."
  fi
fi
echo "-- Done";
echo "";

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

if [ "$(ls -A ${AM_HOME} | grep -i \\.jar\$)" ]; then
  path_amPlugins="${CATALINA_HOME}/webapps/${AM_URI}/WEB-INF/lib/"
  echo "-> Deploying below AM plugins:"
  ls -A ${AM_HOME} | grep -i \\.jar\$
  echo " "
  echo "-- Moving to ${path_amPlugins}"
  mv -f ${AM_HOME}/*.jar ${path_amPlugins}
  echo "-- Done"
  echo " "
fi

if [ ! -d "${AM_PATH_CONFIG}" ]; then
  echo "-- ERROR: Access Manager (AM) Config directory '${AM_PATH_CONFIG}' was NOT found."
  echo "   Please check the base image was built sucessfully."
  echo " "
  errorFound="true"
fi

if [ "${errorFound}" == "false" ]; then
  echo "-> Applying Placeholders"
  echo " "

  path_placeholderTmpFile="${AM_PATH_TOOLS}/amupgrade/rules/placeholders/7.0.0-placeholders.groovy"
  echo "-- Placeholder template '${path_placeholderTmpFile}'"
  ${AM_PATH_TOOLS}/amupgrade/amupgrade -i ${AM_PATH_CONFIG}/services -o ${AM_PATH_CONFIG}/services --fileBasedMode --prettyArrays ${path_placeholderTmpFile}
  ${AM_PATH_TOOLS}/amupgrade/amupgrade -i ${AM_PATH_CONFIG}/services -o ${AM_PATH_CONFIG}/services --fileBasedMode --prettyArrays ${AM_PATH_TOOLS}/serverconfig-modification.groovy
  echo "-- Updating 'LDAPv3ForOpenDS' to '&{am.stores.user.type}'"
  cd "${AM_PATH_CONFIG}"
  rawIdRepoValue="LDAPv3ForOpenDS"
  placeholderedIdRepoValue="\&{am.stores.user.type}"
  find . -name '*.json' -type f -exec sed -i "s+$rawIdRepoValue+$placeholderedIdRepoValue+g" {} \;
  echo "-- Done"
  echo " "
  
  # Must be done after applying placeholders as the file appears to be removed during placeholder application
  echo "-> Deploying 'serverconfig.xml'";
  path_tmp01="${AM_PATH_TOOLS}/serverconfig.xml"
  path_serverFolder="${AM_PATH_CONFIG}/services/realm/root/iplanetamplatformservice/1.0/globalconfig/default/com-sun-identity-servers"
  if [ -f "${path_tmp01}" ] && [ -d "${path_serverFolder}" ]; then
    echo "-- Copying file ..."
    cp -p "${path_tmp01}" "${path_serverFolder}/"
  else
    echo "-- ERROR: Either file '${path_tmp01}' or folder '${path_serverFolder}' cannot be found."
    errorFound="true"
  fi
  echo "-- Done";
  echo " ";

  echo "-> Cloning AM Config";
  echo "-- Creating required directories ..."
  mkdir -p "${AM_PATH_CONFIG_BASE}"
  echo "-- Copying config from '${AM_PATH_CONFIG}' to '${AM_PATH_CONFIG_BASE}'"
  cp -Rp ${AM_PATH_CONFIG}/. ${AM_PATH_CONFIG_BASE}
  echo "-- Listing '${AM_PATH_CONFIG_BASE}'"
  ls -ltra ${AM_PATH_CONFIG_BASE}
  echo "-- Done";
  echo " ";
fi

if [ ! -d "${AM_PATH_CONFIG_BASE}" ]; then
  echo "-- ERROR: Access Manager (AM) Base Config directory '${AM_PATH_CONFIG_BASE}' was NOT found."
  echo "   Please check the base image was built sucessfully."
  echo " "
  errorFound="true"
fi

if [ "${errorFound}" == "true" ]; then
  echo "-- ERROR: See above for more details. Exiting ..."
  exit 1
fi