path_tmpDir="/tmp"

# ----------------------------------------------------------------------------------
# This exports amster Applications and Policies configurations from the Access Manager
# 
# Parameters:
# - ${1} Access Manager(AM) Server URL
# - ${2} AM Config folder path
# - ${3} Path to save Amster export archive to save export data
# - ${4} Path to log file for process 
# ----------------------------------------------------------------------------------
function exportAppsAndPolicies(){ 
  #local path_tmpDir="/tmp"
  local path_amsterHome="/opt/tools/amster"
  local path_amstercript="${path_tmpDir}/exportAppPolicyConfigs.amster"
  local skipProcessing="false"
  local amServerUrl="${1}"
  local path_amConfigDir="${2}"
  local path_amsterExportFile="${3}"
  local path_amsterLogFile="${4}"
  local path_amsterExportDir="${path_tmpDir}/$(date +%s)/amster"
  local path_amsterRSAkey="${path_amConfigDir}/amster_rsa"
  local path_tmp01=
  echo ""
  echo "Exporting Amster Data into Archive"
  echo "----------------------------------"
  echo ""
  echo "-- [ Parameters ]"
  echo "   > amServerUrl: '${amServerUrl}'"
  echo "   > path_amConfigDir: '${path_amConfigDir}'"
  echo "   > path_amsterExportFile: '${path_amsterExportFile}'"
  echo "   > path_amsterLogFile: '${path_amsterLogFile}'"
  echo ""

  echo "-- Creating required folders ..."
  mkdir -p "${path_tmpDir}" "${path_amsterExportDir}"

  path_tmp01="$(dirname ${path_amsterExportFile})"
  if [ ! -d "${path_tmp01}" ]; then
    echo "-- Creating export folder '${path_tmp01}' ..."
    mkdir -p "${path_tmp01}";
  fi
  echo "-- Deleting imported .tar files that are a hour+ old ..."
  find "${path_tmp01}" -name '*.tar' -mmin +59 -delete > /dev/null

  echo "-- Cleaning folder '${path_amsterExportDir}/*'"
  rm -rf "${path_amsterExportDir}/*"

  if [ -z "${amServerUrl}" ]; then
    echo "-- ERROR: Either amServerUrl is empty."
    skipProcessing="true"
  fi
  if [ ! -f "${path_amsterRSAkey}" ]; then
    echo "-- ERROR: Amster key '${path_amsterRSAkey}' NOT found"
    skipProcessing="true"
  fi
  if [ ! -f "${path_amsterRSAkey}" ]; then
    echo "-- ERROR: Amster RSA key '${path_amsterRSAkey}' does NOT exists."
    skipProcessing="true"
  fi
  {
    echo "connect \"${amServerUrl}\" -k \"${path_amsterRSAkey}\""
    echo "export-config --path \"${path_amsterExportDir}\" --globalEntities ' ' --realmEntities 'OAuth2Clients IdentityGatewayAgents J2eeAgents WebAgents SoapStsAgents Policies CircleOfTrust Saml2Entity Applications TrustedJwtIssuer ResourceTypes'"
    echo ':exit;'
  } > "${path_amstercript}"
  if [ ! -f "${path_amstercript}" ]; then
    echo "-- ERROR: Amster script '${path_amstercript}' does NOT exists."
    skipProcessing="true"
  fi
  if [ ! -d "${path_amConfigDir}" ]; then
    echo "-- WARN: '${path_amConfigDir}' does NOT exists. Creating ..."
    mkdir -p "${path_amConfigDir}"
  fi
  if [ ! -d "${path_amsterExportDir}" ]; then
    echo "-- WARN: '${path_amsterExportDir}' does NOT exists. Creating ..."
    mkdir -p "${path_amsterExportDir}"
  fi

  if [ "${skipProcessing}" == "false" ]; then
    # Code referenced from https://github.com/ForgeRock/forgeops
    echo "-- Executing amster export ..."
    ${path_amsterHome}/amster "${path_amstercript}" >> "${path_amsterLogFile}" 2>&1
    #cat "${path_amsterLogFile}"
    # This is a workaround to test if the import failed, and return a non zero exit code if it did
    # See https://bugster.forgerock.org/jira/browse/OPENAM-11431
    if grep -q 'ERROR\|Configuration\ failed\|Could\ not\ connect\|No\ connection\|Unexpected\ response' <"${path_amsterLogFile}"; then
      echo "-- ERROR: See above logs for more info on errors."
    fi
    echo "-- Execution completed"
    echo ""
    #path_amsterExportFile="${path_tmpDir}/amster-export-$(date +"%Y%m%d_%H%M%S").tar"
    if [ -z "$(ls -A ${path_amsterExportDir})" ]; then
      echo "-- WARN: No export files found in '${path_amsterExportDir}'. Skipping export archive creation."
    else
      echo "-- Archiving Amster export in '${path_amsterExportDir}' to '${path_amsterExportFile}'"
      cd "${path_amsterExportDir}";
      tar -cf "${path_amsterExportFile}" "../amster"
    fi
  fi
  echo "-- Done"
  echo ""

  echo "-> Cleaning up"
  rm -rf "(dirname ${path_amsterExportDir})"
  echo "-- Done"
  echo ""

  if [ "${skipProcessing}" == "true" ]; then
    echo "-- ERROR: See above logs for more info. Exiting ..."
    exit 1
  fi
}

# ----------------------------------------------------------------------------------
# This imports amster Applications and Policies configurations from Amster archive
# 
# Parameters:
# - ${1} Access Manager(AM) Server URL
# - ${2} AM Config folder path
# - ${3} Path to save Amster export archive to import
# - ${4} Path to log file for process
# ----------------------------------------------------------------------------------
function importAppsAndPolicies(){
  #local path_tmpDir="/tmp"
  local path_amsterHome="/opt/tools/amster"
  local path_amstercript="${path_tmpDir}/importAppPolicyConfigs.amster"
  local skipProcessing="false"
  local amServerUrl="${1}"
  local path_amConfigDir="${2}"
  local path_amsterExportFile="${3}"
  local path_amsterLogFile="${4}"
  local path_amsterExportDir="${path_tmpDir}/amster-import-$(date +%s)"
  local path_amsterRSAkey="${path_amConfigDir}/amster_rsa"
  local path_tmp01=
  echo ""
  echo "Importing Amster Data from Archive"
  echo "----------------------------------"
  echo ""
  echo "-- [ Parameters ]"
  echo "   > amServerUrl: '${amServerUrl}'"
  echo "   > path_amConfigDir: '${path_amConfigDir}'"
  echo "   > path_amsterExportFile: '${path_amsterExportFile}'"
  echo "   > path_amsterLogFile: '${path_amsterLogFile}'"
  echo ""

  echo "-- Creating required folders ..."
  mkdir -p "${path_tmpDir}" "${path_amsterExportDir}"

  echo "-- Cleaning folder '${path_amsterExportDir}/*'"
  rm -rf "${path_amsterExportDir}/*"

  if [ -z "${amServerUrl}" ]; then
    echo "-- ERROR: Either amServerUrl is empty."
    skipProcessing="true"
  fi
  if [ ! -f "${path_amsterRSAkey}" ]; then
    echo "-- ERROR: Amster key '${path_amsterRSAkey}' NOT found"
    skipProcessing="true"
  fi
  if [ ! -f "${path_amsterRSAkey}" ]; then
    echo "-- ERROR: Amster RSA key '${path_amsterRSAkey}' does NOT exists."
    skipProcessing="true"
  fi
  {
    echo "connect \"${amServerUrl}\" -k \"${path_amsterRSAkey}\""
    echo "import-config --path \"${path_amsterExportDir}\" --clean false"
    echo ':exit;'
  } > "${path_amstercript}"
  if [ ! -f "${path_amstercript}" ]; then
    echo "-- ERROR: Amster script '${path_amstercript}' does NOT exists."
    skipProcessing="true"
  fi
  if [ ! -d "${path_amConfigDir}" ]; then
    echo "-- WARN: '${path_amConfigDir}' does NOT exists. Creating ..."
    mkdir -p "${path_amConfigDir}"
  fi
  if [ ! -d "${path_amsterExportDir}" ]; then
    echo "-- WARN: '${path_amsterExportDir}' does NOT exists. Creating ..."
    mkdir -p "${path_amsterExportDir}"
  fi
  if [ ! -f "${path_amsterExportFile}" ]; then
    echo "-- ERROR: '${path_amsterExportFile}' does NOT exists. Exiting ..."
    skipProcessing="true"
  fi

  if [ "${skipProcessing}" == "false" ]; then
    echo "-- Unarchiving '${path_amsterExportFile}' to '${path_amsterExportDir}'"
    tar -xf "${path_amsterExportFile}" -C "${path_amsterExportDir}"
    
    echo "-- Executing amster import ..."
    ${path_amsterHome}/amster "${path_amstercript}" >> "${path_amsterLogFile}" 2>&1
    #cat "${path_amsterLogFile}"
    # This is a workaround to test if the import failed, and return a non zero exit code if it did
    # See https://bugster.forgerock.org/jira/browse/OPENAM-11431
    if grep -q 'ERROR\|Configuration\ failed\|Could\ not\ connect\|No\ connection\|Unexpected\ response' <"${path_amsterLogFile}"; then
      echo "-- ERROR: See above logs for more info on errors."
    fi
    echo "-- Execution completed"
    echo ""
  fi
  echo "-- Done"
  echo ""

  echo "-> Cleaning up"
  rm -rf "${path_amsterExportFile}" "${path_amsterExportDir}"
  echo "-- Done"
  echo ""

  if [ "${skipProcessing}" == "true" ]; then
    echo "-- ERROR: See above logs for more info. Exiting ..."
    exit 1
  fi
}

executionType="${1}"
serverUrl="${2}"
amConfigDir="${3}"
path_amsterExportFile="${4}"
path_amsterExportLog="${5}"

echo "-- INFO: executionType is ${executionType}" > "${path_amsterExportLog}" 2>&1
echo "1"

case "${executionType}" in
  "import")
    importAppsAndPolicies "${serverUrl}" "${amConfigDir}" "${path_amsterExportFile}" "${path_amsterExportLog}" >> "${path_amsterExportLog}" 2>&1
    ;;
  "export")
    exportAppsAndPolicies "${serverUrl}" "${amConfigDir}" "${path_amsterExportFile}" "${path_amsterExportLog}" >> "${path_amsterExportLog}" 2>&1
    ;;
  *)
    echo "-- ERROR: Invalid executionType. Exitign ..." >> "${path_amsterExportLog}" 2>&1
    ;;
esac

