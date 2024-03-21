function export-diff-to-tar() {
  local path_diffJson="${1}" diffQueryType="${2}"
  local tarPathPrefixToRemove="${3}" path_diffArchive="${4}"
  local sourceFileName= tmpVal= currDir="$(pwd)"
  local path_tmp01=""
  echo ""
  echo "-> Export to .tar started"
  echo "  > path_diffJson: ${path_diffJson}"
  echo "  > diffQueryType: ${diffQueryType}"
  echo "  > tarPathPrefixToRemove: ${tarPathPrefixToRemove}"
  path_tmp01="$(dirname ${path_diffArchive})"
  if [ ! -d "${path_tmp01}" ]; then
    echo "-- Creating export folder '${path_tmp01}' ..."
    mkdir -p "${path_tmp01}";
  fi
  echo "-- Deleting exported .tar files that are a hour+ old ..."
  find "${path_tmp01}" -name '*.tar' -mmin +59 -delete > /dev/null
  echo "-- Done"
  cat "${path_diffJson}" | jq -r '.[].path' | while read -r path; do
    if [ -f "${path}" ]; then
      tar -Puvf "${path_diffArchive}" ${path} --transform="s|$tarPathPrefixToRemove/||" &>/dev/null
      echo "-- Added '${path}'"
    fi
  done
  echo "-- Export to .tar complete"
  echo
}

function applyConfigPlaceholders(){
  echo "[ Placeholders ]"
  echo ""
  
  echo "-> Back up 'serverconfig.xml'"
  path_serverconfigXml="${CONFIG_DIR}/services/realm/root/iplanetamplatformservice/1.0/globalconfig/default/com-sun-identity-servers/serverconfig.xml"
  path_tmp01="/tmp/serverconfig.xml"
  if [ -f "${path_serverconfigXml}" ]; then
    echo "-- In progress ..."
    cp "${path_serverconfigXml}" "${path_tmp01}"
  else
    echo "-- ERROR: File '${path_serverconfigXml}' cannot be found."
    errorFound="true"
  fi
  echo "-- Done";
  echo " ";

  echo "-> Applying Placeholders"
  path_placeholderTmpFile="${TOOLS_HOME}/amupgrade/rules/placeholders/7.0.0-placeholders.groovy"
  if [ -f "${path_placeholderTmpFile}" ]; then
    echo "-- Placeholder template '${path_placeholderTmpFile}'"
    ${TOOLS_HOME}/amupgrade/amupgrade -i ${CONFIG_DIR}/services -o ${CONFIG_DIR}/services --fileBasedMode --prettyArrays ${path_placeholderTmpFile}
    #${TOOLS_HOME}/amupgrade/amupgrade -i ${FACT_HOME}/base-config/services -o ${FACT_HOME}/base-config/services --fileBasedMode --prettyArrays ${path_placeholderTmpFile}
  else
    echo "-- ERROR: File '${path_placeholderTmpFile}' NOT found. Skipping update of config files with placeholders."
     errorFound="true"
  fi
  echo "-- Done"
  echo ""

  # Must be done after applying placeholders as the file appears to be removed during placeholder application
  echo "-> Restoring 'serverconfig.xml'";
  path_serverFolder="${CONFIG_DIR}/services/realm/root/iplanetamplatformservice/1.0/globalconfig/default/com-sun-identity-servers/"
  if [ -f "${path_tmp01}" ] && [ -d "${path_serverFolder}" ]; then
    echo "-- Restoring file ..."
    cp -p "${path_tmp01}" "${path_serverFolder}/"
  else
    echo "-- ERROR: Either file '${path_tmp01}' or folder '${path_serverFolder}' cannot be found."
    errorFound="true"
  fi
  echo "-- Done";
  echo " ";

  if [ "${errorFound}" == "true" ]; then
    echo "-- ERROR: Somehting went wrong. See above logs. Exiting ..."
    exit 1
  fi
}

case "${1}" in
  "config")
    applyConfigPlaceholders
    ;;
  "export")
    path_diffJson="${2}"
    diffQueryType="${3}"
    tarPathPrefixToRemove="${4}"
    path_diffArchive="${5}"
    path_diffLog="${6}"
    if [ -f "${path_diffJson}" ]; then
      if [ -z "${diffQueryType}" ]; then
        echo "-- WARN: Diff type to export is Empty. Setting to 'new-amended'"
        diffQueryType="new-amended"
      fi
      if [ -z "${tarPathPrefixToRemove}" ]; then
        echo "-- WARN: tarPathPrefixToRemove is Empty. Setting to '/opt/am/config'"
        tarPathPrefixToRemove="/opt/am/config"
      fi
      if [ -z "${path_diffArchive}" ]; then
        echo "-- ERROR: Path to Diff archive to be created is empty. Exiting ..."
        exit 1
      fi
      if [ -z "${path_diffLog}" ]; then
        echo "-- ERROR: Path to Diff log file is empty. Exiting ..."
        exit 1
      fi
      export-diff-to-tar "${path_diffJson}" "${diffQueryType}" "${tarPathPrefixToRemove}" "${path_diffArchive}" | sort > "${path_diffLog}"
    else
      echo "-- ERROR: Diff JSON file '${path_diffJson}' does not exists. Exiting ..."
      exit 1
    fi
    ;;
  *)
    echo "-- ERROR: Invalid option '${1}' received. Allowed are 'config', and 'export'"
    exit 1
    ;;
esac
