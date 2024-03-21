#!/usr/bin/env bash

# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

# Forgerock Directory Server (DS) Shared functions
#
# These are typically installed to a known location, such as:
#  - /opt/ds/scripts/forgerock-ds-shared-functions.sh or
#  - ${DS_SCRIPTS}/forgerock-ds-shared-functions.sh
#
# Typically you would 'source' these into another script, e.g.
#  - source /opt/ds/scripts/forgerock-ds-shared-functions.sh or
#  - source "${DS_SCRIPTS}/forgerock-ds-shared-functions.sh"
#
# Important:
# - Any changes made are compatible with all scripts that use these functions
# - Don't check this file into source control with any sensitive values

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
# ========================================================================

source "${MIDSHIPS_SCRIPTS}/midshipscore.sh"

errorFound="false"
path_tmpFolder="/tmp/ds"
path_keystoreFile="${DS_APP}/keystore.p12"
path_keystorePinFile="${DS_APP}/keystore.pin"
file_properties=""
file_schema=""
rootUserPassword=""
monitorUserPassword=""
amIdentityStoreAdminPassword=""
userStoreCertPwd=""
pwdTruststore=""
certificate=""
certificateKey=""
path_sharedFile_ds_setup_done="${DS_HOME}/ds_setup_done"

echo "-> Creating Temp Folder '${path_tmpFolder}'"
mkdir -p "${path_tmpFolder}"
echo "-- Done"
echo ""

# ----------------------------------------------------------------------------------
# This Function ensures the Forgerock Directory Server (DS) binaries are in the
# required location for the execution of the shared functions in this script.
# Must be executed before running first DS binary command on server.
# ----------------------------------------------------------------------------------
function prepareServerFolders() {
  echo "-> Preparing DS server folders"
  local tmpPath_SetupFiles="${DS_HOME}/setupFiles"
  if [ -d "${tmpPath_SetupFiles}" ] && [ -n "$(ls -A "${tmpPath_SetupFiles}")" ]; then
    if [ ! -d "${DS_INSTANCE}" ] || [ -z "$(ls -A "${DS_INSTANCE}")" ]; then
      echo "-- ${DS_INSTANCE} does not exists or is Empty"
      # This needs to be done after the pvc is mounted to ensure on pod termination it can resume.
      # DS files are moved into the pvc location. Make sure Kubernetes pvc is mounted to ${DS_APP}
      echo "-- Copying setup files .."
      cp -R "${tmpPath_SetupFiles}/." "${DS_APP}/"
    fi
    # Remove instance lock file if already exists
    local tmp_instance_file=${DS_INSTANCE}/instance.loc
    if [ -f "${tmp_instance_file}" ]; then
      echo "--  ${tmp_instance_file} exists"
      echo "-- Deleting .."
      rm -f "${DS_INSTANCE}/instance.loc"
    fi
  else
    echo "-- ERROR: DS Setup Files not found at '${tmpPath_SetupFiles}'"
    echo "-- Exiting ..."
    exit 1
  fi
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This function checks if a Forgerock K8s Directory Services (DS) pod is
# Healthy. It will wait for an apredefined time until the server responds
# before it exits.
#
# Parameters:
#  - ${1}  Return Value: 'true' or 'false' if error was found
#  - ${2}:
#    Kubernetes service URL for pod. Format for statefulset pod service URL is
#    {hostname}.{service-name}.{POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}
#  - ${3}: Topology. E.g. 'http' or 'https'
#  - ${4}: TCP Port number. E.g. '8443'
#  - ${5}: This is a multiplier for the ${checkFrequency}
# ----------------------------------------------------------------------------------
function checkDSisHealthy() {
  local svcURL=${2}
  local topology=${3}
  local port=${4}
  local srv_helthyCounter=1
  local checkFrequency=10
  local noOfChecks=${5}
  local responseCodeExpected="200"
  local responseCodeActual=
  local srv_helthyURL="${topology}://${svcURL}:${port}/healthy"

  if [ -z ${5} ] || [ "${5}" == "null" ]; then
    noOfChecks=24
  else
    noOfChecks=${5}
  fi

  echo "-> Checking if DS Server (${svcURL}) is Healthy"
  echo "   URL to check is ${srv_helthyURL}"
  echo "   HTTP Response Code expected is ${responseCodeExpected}"
  while [[ "${responseCodeActual}" != "${responseCodeExpected}" ]];
  do
    responseCodeActual="$(curl -sk -o /dev/null -w "%{http_code}" "${srv_helthyURL}")"
    echo "-- (${srv_helthyCounter}/${noOfChecks}) Returned ${responseCodeActual}. Waiting ${checkFrequency} seconds ..."
    sleep ${checkFrequency}

    if [ ${srv_helthyCounter} == ${noOfChecks} ]; then
      secondsWaitedFor=$(( checkFrequency * noOfChecks ))
      echo "-- Waited for ${secondsWaitedFor} seconds and NO valid response"
      echo "-- Exiting"
      eval "${1}='true'"
      return 2
    fi
    srv_helthyCounter=$(( srv_helthyCounter + 1 ))
  done
  eval "${1}='false'"
  echo "-- Server (${svcURL}) is Healthy"
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This functions configures the below replications server thresholds for the
# desired replication servers:
# - disk-low-threshold
# - disk-full-threshold
#
# Parameters:
#  - ${1}: The DS FQDN
#    Kubernetes service URL for the pod. Format for statefulset pod service URL is
#    {hostname}.{service-name}.{POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}
# - ${2}: The DS Administration port
# - ${3}: The DS Root/Admin User DN
# - ${4}: Bind password for User DN
# - ${5}: At which point to throw a warning that server is running low on disk space
#         Example/Format 10 GB
# - ${6}: At which point (disk free space) to throw a Error and turn off replication
#         Should be smaller than the diskLowThreshold. Example/Format 5 GB
# ----------------------------------------------------------------------------------
function configureReplicationThreshold() {
  local adminConnectorPort=${1}
  local rootUserDN="${2}"
  local bindPassword="${3}"
  local diskLowThreshold="${4}"
  local diskFullThreshold="${5}"
  local dsConfigOfflineMode="${6}"
  local svcURL="${HOSTNAME}.${POD_SERVICE_NAME}.${POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}" # Note that format for statefulset pod service URL is {hostname}.{service-name}.{POD_NAMESPACE}.svc.cluster.local
  local cmdStr=
  local cmdStrUpdated=  
        
  echo "-> Configuring Replication disk space threshold:"
  echo "-- Server: ${svcURL}"
  echo "-- disk-low-threshold:${diskLowThreshold}"
  echo "-- disk-full-threshold:${diskFullThreshold}"
  cmdStr="$( echo ${DS_APP}/bin/dsconfig set-replication-server-prop \
    --provider-name \"Multimaster Synchronization\" \
    --set "disk-low-threshold:${diskLowThreshold}" \
    --set "disk-full-threshold:${diskFullThreshold}" \ )"
  addDsConfigOnlineOfflineAttributes cmdStrUpdated "${cmdStr}" "${dsConfigOfflineMode}" "${svcURL}" "${adminConnectorPort}"  "${rootUserDN}" "${bindPassword}"
  bash <<< "${cmdStrUpdated}"
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This functions adds a trust manager provider to access the server truststore
#
# Parameters:
# ${1}  Return Value: 'true' or 'false' if error was found
# ${2} - dsconfig command string
# ${3} - offline mode? 'true' or 'false'
# ${4} - DS hostname : used ONLY when offline mode is false
# ${5} - DS port : used ONLY when offline mode is false
# ${6} - DS bindDN : used ONLY when offline mode is false
# ${7} - DS bindPassword : used ONLY when offline mode is false
# ----------------------------------------------------------------------------------
function addDsConfigOnlineOfflineAttributes() {
  local cmdString="${2}"
  local offline="${3:-false}"
  local hostname="${4}"
  local port="${5}"
  local bindDN="${6}"
  local bindPassword="${7}"
  if [ "${offline}" == "false" ]; then
    cmdString=${cmdString}$( echo --hostname "'${hostname}'" \
      --port ${port} --bindDN "'${bindDN}'" \
      --bindPassword "'${bindPassword}'" --trustAll \ )
  else
    cmdString=${cmdString}$( echo --offline \ )
  fi
  cmdString=${cmdString}$( echo --no-prompt )
  eval "${1}='${cmdString}'"
}

# ----------------------------------------------------------------------------------
# This functions adds a trust manager provider to access the server truststore
#
# Parameters:
#  - ${1}: ${svcURL}:
#    Kubernetes service URL for the pod. Format for statefulset pod service URL is
#    {hostname}.{service-name}.{POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}
#  - ${2}: ${adminConnectorPort}: DS administration port
#  - ${3}: ${rootUserDN}: DS Root User DN
#  - ${4}: ${bindPassword}: Bind password for User DN
#  - ${5}: ${path_truststoreFile}: Path to the DS truststore file 
#  - ${6}: ${pwd_truststore}: DS truststore password
#  - ${7}: Execute DS config command in offline mode. 'true' or 'false'
# ----------------------------------------------------------------------------------
function allowTruststoreAccessByDS() {
  local svcURL="${1}"
  local adminConnectorPort=${2}
  local rootUserDN="${3}"
  local bindPassword="${4}"
  local path_truststoreFile="${5}"
  local pwd_truststore="${6}"
  local dsConfigOfflineMode="${7:-false}"
  local cmdStr=
  local cmdStrUpdated=
  echo "-> Adding a trust manager provider to access the server truststore"
  cmdStr="$( echo ${DS_APP}/bin/dsconfig create-trust-manager-provider \
    --type file-based \
    --provider-name \"Trust Manager Accelerator\" \
    --set enabled:true \
    --set trust-store-file:${path_truststoreFile} \
    --set trust-store-pin:"${pwd_truststore}" \ )"
  addDsConfigOnlineOfflineAttributes cmdStrUpdated "${cmdStr}" "${dsConfigOfflineMode}" "${svcURL}" "${adminConnectorPort}"  "${rootUserDN}" "${bindPassword}"
  bash <<< "${cmdStrUpdated}"
  echo "-- Done"
  echo ""

  echo "-> Using created trust manager for HTTPS connection handler"
  cmdStr="$( echo ${DS_APP}/bin/dsconfig set-connection-handler-prop \
    --handler-name HTTPS \
    --add trust-manager-provider:\"Trust Manager Accelerator\" \ )"
  addDsConfigOnlineOfflineAttributes cmdStrUpdated "${cmdStr}" "${dsConfigOfflineMode}" "${svcURL}" "${adminConnectorPort}"  "${rootUserDN}" "${bindPassword}"
  bash <<< "${cmdStrUpdated}"
  echo "-- Done"
  echo ""

  echo "-> Using created trust manager for LDAPS connection handler"
  cmdStr="$( echo ${DS_APP}/bin/dsconfig set-connection-handler-prop \
    --handler-name LDAPS \
    --add trust-manager-provider:\"Trust Manager Accelerator\" \ )"
  addDsConfigOnlineOfflineAttributes cmdStrUpdated "${cmdStr}" "${dsConfigOfflineMode}" "${svcURL}" "${adminConnectorPort}"  "${rootUserDN}" "${bindPassword}"
  bash <<< "${cmdStrUpdated}"
  echo "-- Done"
  echo ""

  echo "-> Using created trust manager for Synchronisation Provider"
  cmdStr="$( echo ${DS_APP}/bin/dsconfig set-synchronization-provider-prop \
    --provider-name \"Multimaster Synchronization\" \
    --add trust-manager-provider:\"Trust Manager Accelerator\" \ )"
  addDsConfigOnlineOfflineAttributes cmdStrUpdated "${cmdStr}" "${dsConfigOfflineMode}" "${svcURL}" "${adminConnectorPort}"  "${rootUserDN}" "${bindPassword}"
  bash <<< "${cmdStrUpdated}"
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This function sets the Global Server ID for the Forgerock Directory Server (DS)
#
# Parameters:
#  - ${svcURL}:
#    Kubernetes service URL for the pod. Format for statefulset pod service URL is
#    {hostname}.{service-name}.{POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}
#  - ${bindPassword}: Bind password for User DN
#  - ${srvGlbID}: The Global ID for the DS instnace. Value is an Integer.
# ----------------------------------------------------------------------------------
function setDSglobalID() {
  local svcURL="${1}"
  local adminConnectorPort=${2}
  local rootUserDN="${3}"
  local bindPassword="${4}"
  local srvGlbID="${5}"
  echo "-> Setting Server Global ID to ${srvGlbID}"
  ${DS_APP}/bin/dsconfig set-global-configuration-prop \
  --hostname "${svcURL}" \
  --port ${adminConnectorPort} \
  --bindDN "${rootUserDN}" \
  --bindPassword "${bindPassword}" \
  --set server-id:${srvGlbID} \
  --trustAll --no-prompt --offline
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This function sets the Replication Server ID for the Forgerock Directory Server (DS)
#
# Parameters:
#  - ${svcURL}:
#    Kubernetes service URL for the pod. Format for statefulset pod service URL is
#    {hostname}.{service-name}.{POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}
#  - ${bindPassword}: Bind password for User DN
#  - ${srvGlbID}: The Global ID for the DS instnace. Value is an Integer.
# ----------------------------------------------------------------------------------
function setDSreplicationID() {
  local svcURL="${1}"
  local adminConnectorPort=${2}
  local rootUserDN="${3}"
  local bindPassword="${4}"
  local srvGlbID="${5}"
  echo "-> Setting Server Global ID to ${srvGlbID}"
  ${DS_APP}/bin/dsconfig set-replication-server-prop \
  --provider-name "Multimaster Synchronization" \
  --hostname "${svcURL}" \
  --port ${adminConnectorPort} \
  --bindDN "${rootUserDN}" \
  --bindPassword "${bindPassword}" \
  --set replication-server-id:${srvGlbID} \
  --trustAll --no-prompt --offline
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This function displays the current replication status of the specified
# Directory Server/Services (DS)
#
# Parameters:
#  - ${1}: Kubernetes service URL for the DS pod. Format for statefulset pod service URL is
#          {hostname}.{service-name}.{POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}
#  - ${2}: Bind password for User DN
#  - ${3}: Administration port
#  - ${4}: bindDN
# ----------------------------------------------------------------------------------
function getReplicationStatus() {
  local currHost="${1}"
  local bindPassword=${2}
  local adminConnectorPort=${3}
  local bindDN="${4}"
  echo "-> Getting Replication status for '${currHost}' ..."
  ${DS_APP}/bin/dsrepl status \
    --hostname "${currHost}" \
    --bindDn "${bindDN}" \
    --bindPassword "${bindPassword}" \
    --port ${adminConnectorPort} \
    --trustAll --showReplicas --no-prompt
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This function initializes replication for from one Directory Server (DS)
# to another server in the topology.
#
# Parameters:
#  - ${1}: Kubernetes service URL for the source server. Format for statefulset pod service URL is
#          {hostname}.{service-name}.{POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}
#  - ${2}: Destination DS Server ID
#  - ${3}: Bind password for User DN
#  - ${4}: baseDN to be replicated
#  - ${5}: Administration port
#  - ${6}: bindDN
# ----------------------------------------------------------------------------------
function initializeReplication() {
  local svcURL_source="${1}"
  local svcURL_dest="${2}"
  local bindPassword="${3}"
  local adminConnectorPort=${5}
  local baseDn="${4}"
  local bindDN="${6}"

  echo "-> Replication Initialization Summary"
  echo "   Source: ${svcURL_source}"
  echo "   Destination: ${svcURL_dest}"
  echo ""

  echo "-- Getting Server ID for destination server (${svcURL_dest})"
  serverID=$(echo $(${DS_APP}/bin/dsconfig get-global-configuration-prop \
            --bindDN "${bindDN}" --record --bindPassword "${bindPassword}" \
            --hostname "${svcURL_dest}" --port ${adminConnectorPort} --property server-id \
            --trustAll --no-prompt) | tr -d '\n' | grep -oE '[^ ]+$')
  echo "-- Server ID is ${serverID}"
  echo "-- Done"
  echo ""

  echo "-- Initializing replication for ${baseDn}"
  ${DS_APP}/bin/dsrepl initialize \
  --baseDN "${baseDn}" \
  --bindDN "${bindDN}" \
  --bindPassword "${bindPassword}" \
  --hostname "${svcURL_source}" \
  --toServer "${serverID}" \
  --port ${adminConnectorPort} \
  --trustAll
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This function initializes replication for all Forgerock Directory Server (DS)
# servers in the topology.
#
# Parameters:
#  - ${1}: Kubernetes service URL for the source server. Format for statefulset pod service URL is
#          {hostname}.{service-name}.{POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}
#  - ${2}: Bind password for User DN
#  - ${3}: baseDN to be replicated
#  - ${4}: Administration port
#  - ${5}: bindDN
# ----------------------------------------------------------------------------------
function initializeReplication_allServers() {
  local svcURL_source="${1}"
  local bindPassword="${2}"
  local baseDn="${3}"
  local adminConnectorPort=${4}
  local bindDN="${5}"
  echo "-> Initializing replication for ${baseDn}"
  echo "   Source: ${svcURL_source}"
  echo "   Destination: All Servers"
  ${DS_APP}/bin/dsrepl initialize \
  --baseDN "${baseDn}" \
  --bindDN "${bindDN}" \
  --bindPassword "${bindPassword}" \
  --hostname "${svcURL_source}" \
  --port ${adminConnectorPort} \
  --toAllServers --trustAll
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This function starts the Directory Server (DS)
#
# Parameters:
#  - ${1}: type. Start DS in 'background' or 'foreground'
#  - ${2}: DS protocol. 'http' or 'https'. Default 'https'
#  - ${3}: DS protocol port. E.g. 8080. Default 8443
# ----------------------------------------------------------------------------------
function startDS() {
  local startUpType="${1}"
  local dsProtocol="${2}"
  local dsProtocolPort="${3}"

  echo "-> Starting Directory Server (DS)"
  if [ "${startUpType,,}" != "foreground" ] && [ "${startUpType,,}" != "background" ]; then
    echo "-- startUpType(${startUpType}) was not 'foreground' or 'background'. Setting to 'foreground'"
    startUpType="foreground"
  fi

  if [ "${startUpType,,}" == "background" ]; then
    echo "-- Starting server in background ..."
    nohup ${DS_APP}/bin/start-ds > ${path_tmpFolder}/serverstart.log &
    if [ -z "${dsProtocol}" ]; then
      echo "-- WARN: dsProtocol is empty. Setting to 'https'."
      dsProtocol="https"
    fi
    if [ -z "${dsProtocolPort}" ]; then
      echo "-- WARN: dsProtocolPort is empty. Setting to '8443'."
      dsProtocolPort="8443"
    fi
    checkServerIsAlive --svc "${HOSTNAME}" --type "ds" --channel "${dsProtocol}" --port "${dsProtocolPort}"
  elif [ "${startUpType,,}" == "foreground" ]; then
    {
      echo "-- Cleaning up ..."
      rm -rf ${path_tmpFolder}/*
      echo "-- Done"
      echo ""

      echo "-- Getting Server Status (offline)"
      ${DS_APP}/bin/status --offline
      echo "-- Done"
      echo ""

      if [ ! -f "${DS_VERSION_PATH}" ]; then
        echo "-- Logging DS_VERSION(${DS_VERSION})"
        echo "-- Saving to ${DS_VERSION_PATH}"
        echo -n "${DS_VERSION}" > "${DS_VERSION_PATH}"
        echo "-- Saved to file"
        echo "-- Done"
        echo ""
      fi

      unsetEnvVarsWithSecerts
      addSharedFile ${path_sharedFile_ds_setup_done} "ds-setup-done" # Notify Startup probe

      echo "-> Server starting in foreground ..."
    } 2>&1 | tee -a "${path_setupLog_DS}"
    ${DS_APP}/bin/start-ds --nodetach
  fi
}

# ----------------------------------------------------------------------------------
# This function stop the Directory Server (DS)
# ----------------------------------------------------------------------------------
function stopDS() {
  echo "-> Stopping server ..."
  ${DS_APP}/bin/stop-ds
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# Check if Directory Server (DS) is installed before starting in the foreground
#
# Parameters:
#  - ${1}  backupBeforeUpgrade: Option to backup before an upgrade is done. Allowed values 'true' or 'false'.
#  - ${2}  loadCustomDsConfig: Option to execute custom DS config script. Allowed values 'true' or 'false'.
#  - ${3}  loadCustomSchema: Option to load custom DS schema file. Allowed values 'true' or 'false'.
#  - ${4}  loadCustomJavaProps: Option to load custom java properties file. Allowed values 'true' or 'false'.
#  - ${5}  disableInsecureComms: Option to enable/disable insecure protocols like 'http' and 'ldap'. Allowed values 'true' or 'false'.
#  - ${6}  baseDn: DS Base DN to manage.
#  - ${7}  dsAdminPort: The administration port for the DS instance
#  - ${8}  dsAdminDn: The DN of the DS administratrative user
#  - ${9} dsAdminPwd: The password of the DS administratrative user
#  - ${10} dsProtocol: REST Protocol for DS. Allowed values 'https', 'http'
#  - ${11} dsProtocolPort: Port fot DS protocol. For instance '8443' if Protocol was set to 'https'
#  - ${12} Type of DS. Allowed 'rs', 'rs-aps', 'rs-ts', 'rs-us', 'us', 'aps', 'ts' (No SPACE in string)
#  - ${13} DS certificate alias
#  - ${14}: Bash array of DS Certs paths and Aliases. E.g. "/opt/ds/secrets/us!user-store /opt/ds/secrets/ts!token-store"
# ----------------------------------------------------------------------------------

function setupOrStartDs() {
  local backupBeforeUpgrade="${1}"
  local loadCustomDsConfig="${2}"
  local loadCustomSchema="${3}"
  local loadCustomJavaProps="${4}"
  local disableInsecureComms="${5}"
  local baseDn="${6}"
  local dsAdminPort="${7}"
  local dsAdminDn="${8}"
  local dsAdminPwd="${9}"
  local dsProtocol="${10}"
  local dsProtocolPort="${11}"
  local dsType="${12}"
  local dsCertAlias="${13}"
  local dsTrustedCertsCsv="${14}"
  local dsConfigOfflineMode="true"
  local svcURL=

  if [ -z "${backupBeforeUpgrade}" ]; then
    echo "-- WARN: backupBeforeUpgrade is empty. Setting to 'true'"
    backupBeforeUpgrade="true"
  fi
  if [ -z "${loadCustomDsConfig}" ]; then
    echo "-- WARN: loadCustomDsConfig is empty. Setting to 'true'"
    loadCustomDsConfig="true"
  fi
  if [ -z "${loadCustomSchema}" ]; then
    echo "-- WARN: loadCustomSchema is empty. Setting to 'false'"
    loadCustomSchema="false"
  fi
  if [ -z "${loadCustomJavaProps}" ]; then
    echo "-- WARN: loadCustomJavaProps is empty. Setting to 'true'"
    loadCustomJavaProps="true"
  fi
  if [ -z "${disableInsecureComms}" ]; then
    echo "-- WARN: disableInsecureComms is empty. Setting to 'true'"
    disableInsecureComms="true"
  fi
  if [ -z "${baseDn}" ]; then
    echo "-- ERROR: baseDn is empty."
    errorFound="true"
  fi
  if [ -z "${dsAdminPort}" ]; then
    echo "-- ERROR: dsAdminPort is empty."
    errorFound="true"
  fi
  if [ -z "${dsAdminDn}" ]; then
    echo "-- ERROR: dsAdminDn is empty."
    errorFound="true"
  fi
  if [ -z "${dsAdminPwd}" ]; then
    echo "-- ERROR: dsAdminPwd is empty."
    errorFound="true"
  fi
  if [ -z "${dsProtocol}" ]; then
    echo "-- ERROR: dsProtocol is empty."
    errorFound="true"
  fi
  if [ -z "${dsProtocolPort}" ]; then
    echo "-- ERROR: dsProtocolPort is empty."
    errorFound="true"
  fi
  if [ -z "${dsType}" ]; then
    echo "-- ERROR: dsType is empty. Allowed values 'rs', 'rs-aps', 'rs-ts', 'rs-us', 'us', 'aps', 'ts' (No SPACE in string)"
    errorFound="true"
  fi
  if [ -z "${dsCertAlias}" ]; then
    echo "-- ERROR: dsCertAlias is empty."
    errorFound="true"
  fi
  
  setupDsPrereqs errorFound "${dsType}" "${dsCertAlias}" "${dsTrustedCertsCsv}"
  
  if [ ! -d "${DS_INSTANCE}/db" ]; then
    setupNewDS errorFound "${dsType}" "${dsCertAlias}"
  else
    if [ -f "${DS_INSTANCE}/locks/server.lock" ]; then
      echo "-> Removing ${DS_INSTANCE}/locks/server.lock from potential previous pod termination"
      rm -f ${DS_INSTANCE}/locks/server.lock
      echo "-- Done"
      echo ""
    fi

    if [ "${errorFound}" == "false" ]; then
      # Offline activities
      loadDsSchema "${loadCustomSchema,,}"
      setupCustomJavaProperties errorFound "${loadCustomJavaProps}" "${DS_HOME}"
      disableInsecureCommsDS "${disableInsecureComms}" "${svcURL}" "${dsAdminPort}" "${dsAdminDn}" "${dsAdminPwd}" "${dsConfigOfflineMode}"
      upgradeDS errorFound "${backupBeforeUpgrade}"
      if [ -z "${baseDn}" ] || $(echo "${dsType,,}" | grep -q "rs"); then
        echo "-- WARN: baseDn (${baseDn}) is either empty or dsType (${dsType,,}) is a Replication Server."
        echo "   Skipping rebuilding of Degraded Indexes ..."
        echo ""
      else
        rebuildDegradedIndexes errorFound "${baseDn}"
      fi

      if [ "${errorFound}" == "false" ]; then
        echo "Directory Server already configured"
        echo "-----------------------------------"
        echo "-- ${DS_INSTANCE}/db found. Proceeding to start DS ..."
        echo ""

        checkIntraRsIsAlive "${SELF_REPLICATE}" "${RS_LIST_INTRA_CLUSTER}"
        
        { # Run in background while DS is starting up
          svcURL="${HOSTNAME}.${POD_SERVICE_NAME}.${POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}" # Note that format for statefulset pod service URL is {hostname}.{service-name}.{POD_NAMESPACE}.svc.cluster.local
          checkDSisHealthy errorFound "${svcURL}" "${PROTOCOL_REST}" "${PORT_REST}"
          if [ "${errorFound}" == "false" ]; then
            executeDsConfigScript "${loadCustomDsConfig,,}" "${dsProtocol}" "${dsProtocolPort}";
            echo "-- INFO: Startup process completed successfully"
            echo ""
          fi
        } &
      fi
    fi
  fi
  [ "${errorFound}" == "false" ] && startDS "foreground" || showMessage "error" "Failed to setup or start Directory Server (${DS_TYPE})" "true"
}

# ----------------------------------------------------------------------------------
# Detect Pod resources and update JVM as required
# ----------------------------------------------------------------------------------
function optimizeJVMforPod(){
  echo "-> Java Experimental VM Settings"
  java -XX:+UnlockExperimentalVMOptions -XshowSettings:vm -version
  echo ""
}

# ----------------------------------------------------------------------------------
# This function checks disables HTTP and LDAP handlers for Directory Server (DS)
#
# Parameters:
#  - ${1}: disableInsecureComms. A 'true' or 'false'
#  - ${2}: Kubernetes service URL for the DS server to update. Format for statefulset pod service URL is
#          {hostname}.{service-name}.{POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}
#  - ${3}: Administration port
#  - ${4}: rootUserDN
#  - ${5}: rootUserPassword
#  - ${6}: dsConfigOfflineMode. 'true' or 'false'
# ----------------------------------------------------------------------------------
function disableInsecureCommsDS()  {
  local dsConfigOfflineMode="${1:-false}"
  local cmdStr=
  local cmdStrUpdated=
  if [ "${1}" == "true" ]; then
    echo "Disabling Insecure Communications (HTTP and LDAP)"
    echo "-------------------------------------------------"
    setDSHandlerStatus  "${2}" ${3} "${4}" "${5}" "LDAP" "false" "${dsConfigOfflineMode}"
    setDSHandlerStatus  "${2}" ${3} "${4}" "${5}" "HTTP" "false" "${dsConfigOfflineMode}"
  else
    echo "-> Disabling Confidentiality Mode / Secure Authentication"
    cmdStr="$( echo ${DS_APP}/bin/dsconfig set-password-policy-prop \
      --policy-name Default\ Password\ Policy \
      --set require-secure-authentication:false \ )"
    addDsConfigOnlineOfflineAttributes cmdStrUpdated "${cmdStr}"  "${dsConfigOfflineMode}" "${2}" "${3}"  "${4}" "${5}"
    bash <<< "${cmdStrUpdated}"
    echo "-- Done"
    echo ""
  fi
}

# ----------------------------------------------------------------------------------
# This function checks if a custom javaProperties file is required and if so,
# downloads and load it onto the server.
#
# Parameters:
#  - ${1}: Return Value: 'true' or 'false' if error was found
#  - ${2}: 'true' or 'false' variable indicating whether or not to use a custom javaProperties file
#  - ${3}: Path of folder containing java.properties
# ----------------------------------------------------------------------------------
function setupCustomJavaProperties()  {
  local errorFound="false"
  local useCustomJavaProp="${2}"
  local path_javaPropsDirSrc="${3}"
  local path_javaPropsDirDest="${DS_INSTANCE}/config"
  local path_cmJavaProps=
  echo "-> Enabling custom Java properties"
  if [ "${useCustomJavaProp}" == "true" ]; then
    path_cmJavaProps="${path_javaPropsDirSrc}/java.properties"
    if [ -f "${path_cmJavaProps}" ] && [ -d "${path_javaPropsDirDest}" ]; then
      echo "-- Copying '${path_cmJavaProps}' to '${path_javaPropsDirDest}/'"
      cp -R "${path_cmJavaProps}" "${path_javaPropsDirDest}/"
    else
      echo "-- ERROR: Either -"
      echo " > '${path_cmJavaProps}' NOT found and/or"
      echo " > '${path_javaPropsDirDest}' NOT found"
      errorFound="true"
    fi
  else
    echo "-- Doing nothing as 'LOAD_CUSTOM_JAVA_PROPS' is not set to 'true'"
  fi
  eval "${1}='${errorFound}'"
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This function disables a Directory Server (DS) Handler
#
# Parameters:
#  - ${1}: The hostname of the current host
#  - ${2}: The administration connection port for DS
#  - ${3}: The Root User DN for the DS
#  - ${4}: The path to the file containing the password for the Root User DN
#  - ${5}: DS Handler Name
#  - ${6}: Required status of DS Handler. Must be 'true' or 'false'
#  - ${7}: dsConfigOfflineMode. 'true' or 'false'
# ----------------------------------------------------------------------------------
function setDSHandlerStatus()  {
  local currHost="${1}"
  local dsAdminPort=${2}
  local dsBindDN="${3}"
  local bindPassword="${4}"
  local dsHandlerName="${5}"
  local dsHandlerStatus="${6,,}"
  local dsConfigOfflineMode="${7:-false}"
  local cmdStr=
  local cmdStrUpdated=

  echo "-> Setting Handler(${dsHandlerName}) to ${dsHandlerStatus}"
  if [ "${dsHandlerStatus,,}" != "true" ] && [ "${dsHandlerStatus,,}" != "false" ]; then
    echo "-- Provided status (${dsHandlerStatus}) is not 'true' or 'false'."
    echo "-- Leaving function ..."
    echo "-- Done"
  else
    echo "-- Executing command ..."
    cmdStr="$( echo ${DS_APP}/bin/dsconfig set-connection-handler-prop \
    --handler-name "${dsHandlerName}" \
    --set enabled:${dsHandlerStatus} \ )"
    addDsConfigOnlineOfflineAttributes cmdStrUpdated "${cmdStr}"  "${dsConfigOfflineMode}" "${currHost}" "${dsAdminPort}"  "${dsBindDN}" "${bindPassword}"
    bash <<< "${cmdStrUpdated}"
    echo "-- Done"
  fi
  echo ""
}

# ----------------------------------------------------------------------------------
# This functions configures logging to be streamed as JSON to STDOUT
#
# Parameters:
#  - ${svcURL}:
#    Kubernetes service URL for the pod. Format for statefulset pod service URL is
#    {hostname}.{service-name}.{POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}
# - ${bindPassword}: Bind password for User DN
# ----------------------------------------------------------------------------------
function configureJSONStdoutLogs() {
  local svcURL=${1}
  local adminConnectorPort=${2}
  local rootUserDN=${3}
  local bindPassword=${4}
  echo "Configuring JSON STDOUT Logging"
  echo "-------------------------------"
  echo "Server: ${svcURL}"
  echo ""
  echo "-> Trust Transaction IDs from publishers"
  ${DS_APP}/bin/dsconfig set-global-configuration-prop --advanced \
    --hostname "${svcURL}" --port ${adminConnectorPort} --bindDN "${rootUserDN}" \
    --bindPassword "${bindPassword}" --set trust-transaction-ids:true \
    --no-prompt --trustAll --offline
  echo "-- Done"
  echo ""

  echo "-> Deleting file based loggers"
  ${DS_APP}/bin/dsconfig delete-log-publisher --publisher-name "File-Based Error Logger" --force --hostname "${svcURL}" --port ${adminConnectorPort} --bindDN "${rootUserDN}" --bindPassword "${bindPassword}" --no-prompt --trustAll --offline 
  ${DS_APP}/bin/dsconfig delete-log-publisher --publisher-name "File-Based Access Logger" --force --hostname "${svcURL}" --port ${adminConnectorPort} --bindDN "${rootUserDN}" --bindPassword "${bindPassword}" --no-prompt --trustAll --offline 
  ${DS_APP}/bin/dsconfig delete-log-publisher --publisher-name "File-Based Audit Logger" --force --hostname "${svcURL}" --port ${adminConnectorPort} --bindDN "${rootUserDN}" --bindPassword "${bindPassword}" --no-prompt --trustAll --offline 
  ${DS_APP}/bin/dsconfig delete-log-publisher --publisher-name "File-Based HTTP Access Logger" --force --hostname "${svcURL}" --port ${adminConnectorPort} --bindDN "${rootUserDN}" --bindPassword "${bindPassword}" --no-prompt --trustAll --offline 
  ${DS_APP}/bin/dsconfig delete-log-publisher --publisher-name "File-Based Debug Logger" --force --hostname "${svcURL}" --port ${adminConnectorPort} --bindDN "${rootUserDN}" --bindPassword "${bindPassword}" --no-prompt --trustAll --offline 
  ${DS_APP}/bin/dsconfig delete-log-publisher --publisher-name "Json File-Based Access Logger" --force --hostname "${svcURL}" --port ${adminConnectorPort} --bindDN "${rootUserDN}" --bindPassword "${bindPassword}" --no-prompt --trustAll --offline 
  ${DS_APP}/bin/dsconfig delete-log-publisher --publisher-name "Json File-Based HTTP Access Logger" --force --hostname "${svcURL}" --port ${adminConnectorPort} --bindDN "${rootUserDN}" --bindPassword "${bindPassword}" --no-prompt --trustAll --offline 
  ${DS_APP}/bin/dsconfig delete-log-publisher --publisher-name "Replication Repair Logger" --force --hostname "${svcURL}" --port ${adminConnectorPort} --bindDN "${rootUserDN}" --bindPassword "${bindPassword}" --no-prompt --trustAll --offline 
  ${DS_APP}/bin/dsconfig delete-log-publisher --publisher-name "Filtered Json File-Based Access Logger" --force --hostname "${svcURL}" --port ${adminConnectorPort} --bindDN "${rootUserDN}" --bindPassword "${bindPassword}" --no-prompt --trustAll --offline 
  echo "-- Done"
  echo ""
  
  echo "-> Creating audit handlers config files"
  echo "{\"class\": \"org.forgerock.audit.handlers.json.stdout.JsonStdoutAuditEventHandler\",\"config\": {\"enabled\": true, \"name\": \"ldap-access.stdout\", \"elasticsearchCompatible\" : false,\"topics\": [\"ldap-access\"]}}" > ${DS_APP}/instance/config/audit-handlers/ldap-json-stdout-config.json
  echo "{\"class\": \"org.forgerock.audit.handlers.json.stdout.JsonStdoutAuditEventHandler\",\"config\": {\"enabled\": true, \"name\": \"http-access.stdout\", \"elasticsearchCompatible\" : false,\"topics\": [\"http-access\"]}}" > ${DS_APP}/instance/config/audit-handlers/http-json-stdout-config.json
  chmod +x ${DS_APP}/instance/config/audit-handlers/ldap-json-stdout-config.json
  chmod +x ${DS_APP}/instance/config/audit-handlers/http-json-stdout-config.json
  echo "-- Done"
  echo ""

  echo "-> Create StdOut audit handlers"
  ${DS_APP}/bin/dsconfig create-log-publisher --publisher-name "Console Error Logger" \
    --type console-error --set enabled:true --set default-severity:error --set default-severity:warning \
    --set default-severity:notice --hostname "${svcURL}" --port ${adminConnectorPort} \
    --bindDN "${rootUserDN}" --bindPassword "${bindPassword}" \
    --no-prompt --trustAll --offline
  ${DS_APP}/bin/dsconfig create-log-publisher --publisher-name "Custom LDAP Access Logger" \
    --type external-access --set enabled:true --set config-file:${DS_APP}/instance/config/audit-handlers/ldap-json-stdout-config.json \
    --hostname "${svcURL}" --port ${adminConnectorPort} --bindDN "${rootUserDN}" --bindPassword "${bindPassword}" \
    --no-prompt --trustAll --offline
  ${DS_APP}/bin/dsconfig create-log-publisher --publisher-name "Custom HTTP Access Logger" \
  --type external-access --set enabled:true --set config-file:${DS_APP}/instance/config/audit-handlers/http-json-stdout-config.json \
  --hostname "${svcURL}" --port ${adminConnectorPort} --bindDN "${rootUserDN}" --bindPassword "${bindPassword}" \
  --no-prompt --trustAll --offline
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# Function to do a in-situ MINOR upgrade of the ForgeRock Directory Server
#
# Parameters:
#  - ${1}: Return Value: 'true' or 'false' if error was found
#  - ${2}: backupBeforeUpgrade: Option to backup before an upgrade is done.
# ----------------------------------------------------------------------------------
function upgradeDS(){
  echo "Checking Directory Server (DS) Upgrade State"
  echo "--------------------------------------------"
  local path_dszip="${DS_HOME}/${DS_FILENAME}"
  local path_BackupFolder="${DS_APP}/instance/bak/$(date +"%Y-%m-%d")"
  local dsVerInstalled=$(cat ${DS_VERSION_PATH})
  local errorFound="false"
  local backupBeforeUpgrade="${2}"
  

  if [ -z "${backupBeforeUpgrade}" ]; then
    echo "-- ERROR: backupBeforeUpgrade is empty. Setting to 'true' by default."
    backupBeforeUpgrade="true"
  fi

  echo "-- Getting installed DS version from (PVC/PV)"
  if [ ! -f "${DS_VERSION_PATH}" ]; then
    echo "-- WARN: Required file '${DS_VERSION_PATH}' NOT found!"
    echo "   Logging current version and Skipping Upgrade process ..."
    echo "-- Saving version '${DS_VERSION}' to ${DS_VERSION_PATH}"
    echo "${DS_VERSION}" > "${DS_VERSION_PATH}"
    echo "-- Done"
    echo ""
  else
    echo "-- Displaying DS Versions:"
    echo "   > Installed (PVC/PV) DS version: ${dsVerInstalled}"
    echo "   > Current DS Image version: ${DS_VERSION}"
    echo ""
    echo "-- Checking if in-situ DS upgrade is required ..."
    if [ $(ver ${DS_VERSION}) -gt $(ver ${dsVerInstalled}) ]; then
      echo "-- Upgrade REQUIRED";
      echo ""

      if [ ! -f "${path_dszip}" ]; then
        echo "-- ERROR: Required file '${path_dszip}' NOT found!"
        echo "   Exiting ..."
        errorFound="true"
      fi

      if [ "${errorFound}" == "false" ]; then
        if [ "${backupBeforeUpgrade,,}" == "true" ]; then
          echo "-> Scheduling Backup (all Backends) to start now"
          echo "-- Creating backup folder '${path_BackupFolder}"
          mkdir -p "${path_BackupFolder}"
          ${DS_APP}/bin/dsbackup create \
            --offline --no-prompt \
            --backupLocation "${path_BackupFolder}"
          if [ $? -ne 0 ]; then
            echo "-- ERROR: An error occurred while backing up the DS Backends."
            echo "   See above log for details. Canceling Upgrade process."
            echo ""
            errorFound="true"
          else
            echo "-- Backup done"
            echo ""
          fi
        fi

        if [ "${errorFound}" == "false" ]; then
          echo "-> Stopping the DS server if started"
          ${DS_APP}/bin/stop-ds
          echo "-- Done"
          echo ""

          echo "-> Preparing the DS ${DS_VERSION} upgrade files"
          echo "-- Upacking to '${DS_HOME}' ..."
          unzip -qq "${path_dszip}" -d ${DS_HOME}
          echo "-- Updating binary files ..."
          cp -R "${DS_HOME}/opendj/." "${DS_APP}/"
          echo "-- Cleaning up ..."
          rm -dr "${DS_HOME}/opendj"
          echo "-- Done"
          echo ""

          echo "[ STARTING DS UPGRADE ]"
          echo "-- Executing the command ..."
          echo ""
          ${DS_APP}/upgrade \
            --no-prompt \
            --acceptLicense \
            --force
          if [ $? -ne 0 ]; then
            echo "-- ERROR: An error occurred performing the DS Upgrade."
            echo "   See above log for details."
            echo "   Remember to restore server from backup if required."
            errorFound="true"
          fi

          if [ "${errorFound}" == "false" ]; then
            echo "-- Upgrade process done"
            echo ""

            echo "-> Logging updated DS_VERSION"
            echo "-- Saving version '${DS_VERSION}' to ${DS_VERSION_PATH}"
            echo "${DS_VERSION}" > "${DS_VERSION_PATH}"
            echo "-- Saved '${DS_VERSION_PATH}' to file"
            echo "-- Done"
            echo ""
          fi
        fi
      fi
    else
      echo "-- Based on versions, NO Upgrade required!";
      echo "-- Done"
      echo ""
    fi
  fi
  eval "${1}='${errorFound}'"
}

# ----------------------------------------------------------------------------------
# This functions schedules backup of all the ForgeRock Directory Services (DS)
# LDAP backends
#
# Parameters:
#  - ${1} backupFrequency : Accepted values 'daily', 'weekly', 'monthly', '<a-cron-string>'
#  - ${2} adminConnectorPort: Port used for DS administration. Usually '4444'.
#  - ${3} rootUserDN: The Bind DN to use to connect to the DS
#  - ${4} bindPassword: Bind password for User DN
#  - ${5} notificationEmail: Email address to send Backup Errors or completion status
# ----------------------------------------------------------------------------------
function scheduleDsBackendsBackup()  {
  echo "Scheduling Backup"
  echo "-----------------"
  echo ""
  echo "-> Backup Frequency explained: All DS backend will be backed-up:"
  echo "   [daily] 2AM daily"
  echo "   [weekly] 2AM every Friday"
  echo "   [monthly] 1st day of every month"
  echo "   [custom] A cron string like '0 2 * * *' for daily at 2AM"
  echo ""
  
  if [ -z "${2}" ] || [ -z "${3}" ] ||
     [ -z "${4}" ] || [ -z "${5}" ]; then
    echo "-- Either one or more of the below parameters are empty:"
    echo "   > ${2} adminConnectorPort is '${adminConnectorPort}'"
    echo "   > ${3} rootUserDN is '${rootUserDN}'"
    echo "   > ${4} bindPassword length is '${#bindPassword}'"
    echo "   > ${5} notificationEmail is '${notificationEmail}'"
    echo "-- Exiting .."
    exit 1
  else
    local backupDate=
    local backupTIme=
    local backupFrequency="${1}"
    local adminConnectorPort="${2}"
    local rootUserDN="${3}"
    local bindPassword="${4}"
    local notificationEmail="${5}"
    local taskId="${RANDOM}"
    local path_BackupFolder="${DS_APP}/instance/bak"
    backupDate="$(date +"%Y-%m-%d")"
    backupTIme="$(date +"%H-%M")"

    if [ -z "${backupFrequency}" ] ||
      [ "${backupFrequency,,}" != "daily" ] &&
      [ "${backupFrequency,,}" != "weekly" ] &&
      [ "${backupFrequency,,}" != "monthly" ] &&
      [ "${backupFrequency,,}" != "custom" ]; then
      echo "-- Invalid backupFrequency () received. Should be either 'daily','weekly','monthly' or 'custom'."
      echo "   Setting to 'daily' as default"
      backupFrequency="daily"
    fi

    echo "-- backupFrequency provided was '${backupFrequency}'"
    case "${backupFrequency}" in
      "daily")
        backupFrequency='0 2 * * *';;
      "weekly")
        backupFrequency='0 2 * * FRI';;
      "monthly")
        backupFrequency='0 2 1 * *';;
      *)
        backupFrequency="${backupFrequency}"
        ;;
    esac

    echo "-- Cron/Backup frequency will be '${backupFrequency}'"
    echo "-- notificationEmail provided was '${notificationEmail}'"
    echo "-- rootUserDN provided was '${rootUserDN}'"
    echo "-- bindPassword provided length was '${#bindPassword}'"
    echo "-- taskId will be ${taskId}"
    echo "-- Creating backup folder '${path_BackupFolder}'"
    mkdir -p "${path_BackupFolder}"
    echo "-- Done"
    echo ""
    echo "-- Scheduling the Backup ..."
    ${DS_APP}/bin/dsbackup create \
      --hostname "localhost" --port ${adminConnectorPort} \
      --bindDN "${rootUserDN}" --bindPassword "${bindPassword}" \
      --backupLocation "${path_BackupFolder}" --recurringTask "${backupFrequency}" \
      --description "DS [${HOSTNAME}] Scheduled backup on ${backupDate} at ${backupTIme}" \
      --taskId "${taskId}" --completionNotify "${notificationEmail}" \
      --errorNotify "${notificationEmail}" --no-prompt --trustAll
    echo "-- Done"
    echo ""

  fi
}

# ----------------------------------------------------------------------------------
# This function enables the Replication Server feature for a Directory Server (DS)
#
# Parameters:
#  - ${1}: Kubernetes service URL for the DS pod. Format for statefulset pod service URL is
#          {hostname}.{service-name}.{POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}
#  - ${2}: Bind password for User DN
#  - ${3}: Administration port
#  - ${4}: bindDN
#  - ${5}: Replication Server Replication Port
# ----------------------------------------------------------------------------------
function createReplicationServer() {
  local currHost="${1}"
  local bindPassword="${2}"
  local adminConnectorPort=${3}
  local bindDN="${4}"
  local setupcommand=
  local replicationPort=${5}
  local path_tmpScript="${path_tmpFolder}/addRSfeature.sh"
  echo "-> Enabling Replication Server config ..."
  setupcommand=$( echo ${DS_APP}/bin/dsconfig create-replication-server \
    --provider-name "'Multimaster Synchronization'" \
    --set replication-port:${replicationPort} \
    --hostname "'${currHost}'" --type generic \
    --port ${adminConnectorPort} \
    --bindDN "'${bindDN}'" \
    --bindPassword "'${bindPassword}'" \
    --trustAll --no-prompt )
  echo "${setupcommand}" > "${path_tmpScript}"
  echo "-- Command setup complete"
  echo "--> Executing command ..."
  bash "${path_tmpScript}"
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# This function adds a Directory Server (DS) as a bootstrap Replication Server (RS)
#
# Parameters:
#  - ${1}: Kubernetes service URL for the DS pod. Format for statefulset pod service URL is
#          {hostname}.{service-name}.{POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}
#  - ${2}: Bind password for User DN
#  - ${3}: Administration port
#  - ${4}: bindDN
#  - ${5}: Comma separated string of bootstrap RS and port to add as bootstrap server(s). E.g.
#          {hostname}.{service-name}.{POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}:{port},{hostname}.{service-name}.{POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}:{port},
# ----------------------------------------------------------------------------------
function addBootstrapReplicationServers() {
  local currHost="${1}"
  local bindPassword="${2}"
  local adminConnectorPort=${3}
  local bindDN="${4}"
  local arrRS_LIST_INTRA_CLUSTER="${5}"
  local setupcommand=
  local path_tmpScript="${path_tmpFolder}/addRSBootstrap.sh"
  echo "-> Adding Below as Bootstrap Replication Server(s) to '${currHost}' ..."
  setupcommand=$( echo ${DS_APP}/bin/dsconfig set-synchronization-provider-prop \
    --provider-name "'Multimaster Synchronization'" \
    --hostname "'${currHost}'" \
    --port ${adminConnectorPort} \
    --bindDN "'${bindDN}'" \
    --set enabled:true \
    --bindPassword "'${bindPassword}'" \ )
  IFS=',' read -ra arrRS_LIST_INTRA_CLUSTER <<< "${arrRS_LIST_INTRA_CLUSTER}"
  for rsSVC  in "${arrRS_LIST_INTRA_CLUSTER[@]}"
  do
    echo "   > ${rsSVC}"
    setupcommand=${setupcommand}$( echo --add bootstrap-replication-server:${rsSVC} \ )
  done
  setupcommand=${setupcommand}$(echo --trustAll --no-prompt)
  echo "${setupcommand}" > "${path_tmpScript}"
  echo "-- Command setup complete"
  echo "--> Executing command ..."
  bash "${path_tmpScript}"
  echo "-- Done"
  echo ""
  # echo "-> Restarting DS for previous command to take effect"
  # ${DS_APP}/bin/stop-ds --restart
  # echo "-- Done"
  # echo ""
}

# ----------------------------------------------------------------------------------
# This Loads a DS Schema fle into the required directory
#
# Parameters:
#  - ${1}: Load DS scema file. Allowed values are 'true' or 'false'
# ----------------------------------------------------------------------------------
function loadDsSchema() {
  local loadSchema="${1}"
  local path_userSchemaFolder="${DS_INSTANCE}/db/schema"
  local path_userSchemaFile="${path_userSchemaFolder}/99-schema.ldif"
  local path_customDsSchema="${DS_CUSTOM_SCHEMA}"
  if [ "${loadSchema,,}" == "true" ]; then
    echo "-> Loading schema file"
    if [ -d "${DS_INSTANCE}" ]; then
      if [ -d "${path_userSchemaFolder}" ]; then
        if [ -f "${path_customDsSchema}" ]; then
          echo "-- Copying schema from '${path_customDsSchema}' to '${path_userSchemaFile}'"
          cp "${path_customDsSchema}" "${path_userSchemaFile}"
          if [ -f "${path_userSchemaFile}" ]; then
            echo "-- Updating the file execution"
            chmod +x "${path_userSchemaFile}"
          else
            echo "-- ERROR: '${path_userSchemaFile}' not found"
            errorFound="true"
          fi
        else
          echo "-- ERROR: '${path_customDsSchema}' not found"
          errorFound="true"
        fi
      else
        echo "-- WARN: Schema folder '${path_userSchemaFolder}' NOT found. Skipping schema setup."
      fi
    else
      echo "-- WARN: Direcetory Server (DS) does not appear to be setup."
      echo "-- DS_INSTANCE folder '${DS_INSTANCE}' NOT found. Skipping schema setup."
    fi
    echo "-- Done"
    echo ""
  fi
}

# ----------------------------------------------------------------------------------
# Executes the pre-defined Directory Server (DS) Configuration Script
#
# Parameters:
# - ${1}: Execute custom DS config script. Allowed values 'true' or 'false'
# - ${2}: REST Protocol for DS. Allowed values 'https', 'http'
# - ${3}: Port fot DS protocol. For instance '8443' if Protocol was set to 'https'
# - ${4}: Start and then Stop DS. Allowed values 'true' or 'false'
# ----------------------------------------------------------------------------------
function executeDsConfigScript() {
  local loadCustomDsConfig="${1}"
  local path_DsConfigFile="${path_tmpFolder}/dsconfig_custom.sh"
  local path_customDsConfigScript="${DS_SCRIPTS}/dsconfig.sh"
  local dsProtocol="${2}"
  local dsProtocolPort="${3}"
  if [ -z "${dsProtocol}" ]; then
    echo "-- WARN: dsProtocol is empty. Setting to 'https'."
    dsProtocol="https"
  fi
  if [ -z "${dsProtocolPort}" ]; then
    echo "-- WARN: dsProtocolPort is empty. Setting to '8443'."
    dsProtocolPort="8443"
  fi
  if [ "${loadCustomDsConfig}" == "true" ]; then
    echo "[ Processing Directory Server (DS) Configuration Script ]"
    echo ""
    if [ -d "${DS_INSTANCE}" ]; then
      if [ -f "${path_customDsConfigScript}" ]; then
        cp "${path_customDsConfigScript}" "${path_DsConfigFile}"
        if [ -f "${path_DsConfigFile}" ]; then
          echo "-- Updating the file '${path_DsConfigFile}' permission for execution"
          chmod +x "${path_DsConfigFile}"
          echo "-- Executing ..."
          echo ""
          source "${path_DsConfigFile}"
        else
          echo "-- ERROR: '${path_DsConfigFile}' not found"
          errorFound="true"
        fi
      else
        echo "-- ERROR: '${path_customDsConfigScript}' not found"
        errorFound="true"
      fi
    else
      echo "-- WARN: Direcetory Server (DS) does not appear to be setup."
      echo "-- DS_INSTANCE folder '${DS_INSTANCE}' NOT found. Skipping config script execution."
      echo "-- Done"
      echo ""
    fi
    if [ "${errorFound}" == "true" ]; then      
      echo "-- ERROR: See above for more details. Exiting ..."
      exit 1
    fi
  fi
}

# -----------------------------------------------------------
# Rebuild Degraded indexes
# 
# Parameters:
#  - ${1}: Return Value: 'true' or 'false' if error was found
#  - ${2}: BaseDN
# -----------------------------------------------------------
function rebuildDegradedIndexes() {
  local errorFound="false"
  local baseDN="${2}"
  
  echo "[ Rebuilding DS Degraded Indexes (Offline) ]"
  if [ -n "${baseDN}" ]; then
    ${DS_APP}/bin/rebuild-index --baseDN "${baseDN}" --rebuildDegraded --offline
  else
    echo "-- ERROR: Based DN provided is empty."
    errorFound="true"
  fi
  eval "${1}='${errorFound}'"
  echo "-- Done"
  echo ""
}

# ----------------------------------------------------------------------------------
# Applies Directory Server (DS) pre-requisites and start up if already configured
#
# Parameters:\
#  - ${1}: Return Value: 'true' or 'false' if error was found
#  - ${2}: Type of DS. Allowed 'rs', 'rs-aps', 'rs-ts', 'rs-us', 'us', 'aps', 'ts' (No SPACE in string)
#  - ${3}: DS Cert Alias
#  - ${4}: Bash array of DS Certs paths and Aliases. E.g. "/opt/ds/secrets/us!user-store /opt/ds/secrets/ts!token-store"
# ----------------------------------------------------------------------------------
function setupDsPrereqs() {
  local dsType="${2}"
  local certAlias="${3}"
  local dsTrustedCertsCsv="${4}"
  local componentNameString=""

  #NOTE: No spaces in componentNameString variable value
  case "${dsType,,}" in
    "rs")
      componentNameString="Replication-Server(RS)"
      ;;
    "rs-aps")
      componentNameString="Replication-Server(RS)-APS"
      ;;
    "rs-ts")
      componentNameString="Replication-Server(RS)-TS"
      ;;
    "rs-us")
      componentNameString="Replication-Server(RS)-US"
      ;;
    "aps")
      componentNameString="Application-Policy-Store(RS)"
      ;;
    "ts")
      componentNameString="Token-Store(TS)"
      ;;
    "us")
      componentNameString="User-Store(US)"
      ;;
    *)
      echo -n "-- ERROR: Invalid DS type '${dsType}' provided. Allowed values are 'rs', 'rs-aps', 'rs-ts', 'rs-us', 'aps', 'ts', 'us' \n"
      errorFound="true"
      ;;
  esac
  
  echo "====================================================================="
  echo "|| ForgeRock Directory Server (DS) - $(printf %-29s ${componentNameString}) ||"
  echo "====================================================================="
  echo "->               HOSTNAME: ${HOSTNAME}"
  echo "->         BACKUP_BACKEND: ${BACKUP_BACKEND}"
  echo "->  BACKUP_BEFORE_UPGRADE: ${BACKUP_BEFORE_UPGRADE}"
  echo "->       BACKUP_FREQUENCY: ${BACKUP_FREQUENCY}"
  echo "->         CLUSTER_DOMAIN: ${CLUSTER_DOMAIN}"
  echo "-> DISABLE_INSECURE_COMMS: ${DISABLE_INSECURE_COMMS}"
  echo "->               DN_ADMIN: ${DN_ADMIN}"
  echo "->                DN_BASE: ${DN_BASE}"
  echo "->                 DS_APP: ${DS_APP}"
  echo "->                DS_TYPE: ${DS_TYPE}"
  echo "->             CERT_ALIAS: ${CERT_ALIAS}"
  echo "->                DS_HOME: ${DS_HOME}"
  echo "->            DS_INSTANCE: ${DS_INSTANCE}"
  echo "->             DS_SCRIPTS: ${DS_SCRIPTS}"
  echo "->             DS_SECRETS: ${DS_SECRETS}"
  echo "->             DS_VERSION: ${DS_VERSION}"
  echo "->               ENV_TYPE: ${ENV_TYPE}"
  echo "->           JAVA_CACERTS: ${JAVA_CACERTS}"
  echo "->              JAVA_HOME: ${JAVA_HOME}"
  echo "->  LOAD_CUSTOM_DS_CONFIG: ${LOAD_CUSTOM_DS_CONFIG}"
  echo "-> LOAD_CUSTOM_JAVA_PROPS: ${LOAD_CUSTOM_JAVA_PROPS}"
  echo "->            LOAD_SCHEMA: ${LOAD_SCHEMA}"
  echo "->               LOG_MODE: ${LOG_MODE}"
  echo "->           POD_BASENAME: ${POD_BASENAME}"
  echo "->          POD_NAMESPACE: ${POD_NAMESPACE}"
  echo "->       POD_SERVICE_NAME: ${POD_SERVICE_NAME}"
  echo "->             PORT_ADMIN: ${PORT_ADMIN}"
  echo "->              PORT_HTTP: ${PORT_HTTP}"
  echo "->             PORT_HTTPS: ${PORT_HTTPS}"
  echo "->              PORT_LDAP: ${PORT_LDAP}"
  echo "->             PORT_LDAPS: ${PORT_LDAPS}"
  echo "->       PORT_REPLICATION: ${PORT_REPLICATION}"
  echo "->              PORT_REST: ${PORT_REST}"
  echo "->          PROTOCOL_REST: ${PROTOCOL_REST}"
  echo "->  REPLICATION_ADMIN_UID: ${REPLICATION_ADMIN_UID}"
  echo "->  RS_LIST_INTRA_CLUSTER: ${RS_LIST_INTRA_CLUSTER}"
  echo "->               REPLICAS: ${REPLICAS}"
  echo "->           SECRETS_MODE: ${SECRETS_MODE}"
  echo "->         SELF_REPLICATE: ${SELF_REPLICATE}"
  if [ "${SECRETS_MODE,,}" != "volume" ]; then
  echo "->SECRETS_MANAGER_BASE_URL: ${SECRETS_MANAGER_BASE_URL}"
  echo "->   SECRETS_MANAGER_TOKEN: ${SECRETS_MANAGER_TOKEN}"
  echo "-> SECRETS_MANAGER_PATH_RS: ${SECRETS_MANAGER_PATH_RS}"
  echo "->SECRETS_MANAGER_PATH_APS: ${SECRETS_MANAGER_PATH_APS}"
  echo "-> SECRETS_MANAGER_PATH_US: ${SECRETS_MANAGER_PATH_US}"
  echo "-> SECRETS_MANAGER_PATH_TS: ${SECRETS_MANAGER_PATH_TS}"
  fi
  echo "======================================================================"
  echo ""

  if [ -n "${INTER_CLUSTER_REPL_ON}" ]; then
    echo "------------------------------------------------------"
    echo "Replication Server (RS) specific Environment variables"
    echo "------------------------------------------------------"
    echo "-> INTER_CLUSTER_REPL_ON: ${INTER_CLUSTER_REPL_ON}"
    echo "-> RS_LIST_INTER_CLUSTER: ${RS_LIST_INTER_CLUSTER}"
    echo "------------------------------------------------------"
    echo ""
  fi

  if [ "${DS_TYPE,,}" == "us" ]; then
    echo "-----------------------------------------"
    echo "User Store specific Environment variables"
    echo "-----------------------------------------"
    echo "->        LOAD_SCHEMA: ${LOAD_SCHEMA}"
    echo "->       REPO_ADD_IDM: ${REPO_ADD_IDM}"
    echo "->        REPO_DOMAIN: ${REPO_DOMAIN}"
    echo "-----------------------------------------"
    echo ""
  fi

  showEmptyEnvVars errorFound

  if [ -z "${PROTOCOL_REST}" ]; then
    echo "-- ERROR: PROTOCOL_REST is empty. Please set to 'https' or 'http'."
    errorFound="true"
  fi

  if [ -z "${PORT_REST}" ]; then
    echo "-- ERROR: PORT_REST is empty. Please set to the port used by the REST protocol provided in PROTOCOL_REST('${PROTOCOL_REST}'). E.g. 8443"
    errorFound="true"
  fi

  if [ -z "${REPLICAS}" ] || [ "${REPLICAS}" -ne "${REPLICAS}" ] 2>/dev/null; then
    echo "-- WARN: REPLICAS('${REPLICAS}') is not number, setting to '1'"
    export REPLICAS=1
  fi 
  echo ""

  if [ "${errorFound}" == "false" ]; then
    showUlimits
    
    echo "Setting up pre-requsite(s)"
    echo "--------------------------"
    removeSharedFile "${path_sharedFile_ds_setup_done}"
    setEnvVarsWithSecerts "${SECRETS_MODE}" "${DS_SECRETS}" "${SECRETS_MANAGER_TOKEN}" # Must be ran before any Environment variable usage

    # Setting Certs to Trust
    case "${dsType,,}" in
      "rs"|"rs-aps"|"rs-ts"|"rs-us")
        dsTrustedCertsCsv="${SECRET_CERTIFICATE}!${CERT_ALIAS},${SECRET_CERTIFICATE_US}!user-store,${SECRET_CERTIFICATE_TS}!token-store,${SECRET_CERTIFICATE_APS}!app-policy-store"
        ;;
      "aps")
        dsTrustedCertsCsv="${SECRET_CERTIFICATE}!${CERT_ALIAS},${SECRET_CERTIFICATE_RS}!repl-server,${SECRET_CERTIFICATE_AM}!access-manager"
        ;;
      "us"|"ts")
        dsTrustedCertsCsv="${SECRET_CERTIFICATE}!${CERT_ALIAS},${SECRET_CERTIFICATE_RS}!repl-server"
        ;;
      *)
        echo -n "-- ERROR: Invalid DS type '${dsType}' provided. Allowed values are 'rs', 'rs-aps', 'rs-ts', 'rs-us', 'aps', 'ts', 'us' \n"
        errorFound="true"
        ;;
    esac
    if [ -z "${dsTrustedCertsCsv}" ]; then
      echo "-- WARN: dsTrustedCertsCsv is empty. No certificate will be added to the server truststore."
      echo ""
    else
      changeTrustStorePassword "${JAVA_CACERTS}" "changeit" "${SECRET_PASSWORD_TRUSTSTORE}"
      addCertsToTruststore "${JAVA_CACERTS}" "${SECRET_PASSWORD_TRUSTSTORE}" "${dsTrustedCertsCsv}"
    fi
    
    createPKCS12fromCerts "${CERT_ALIAS}" "${SECRET_CERTIFICATE}" "${SECRET_CERTIFICATE_KEY}" "${path_keystoreFile}" "${SECRET_PASSWORD_KEYSTORE}"
  else
    echo -e "-- ERROR: Something went wrong. See above log for details. Exiting ...\n"
  fi
  eval "${1}='${errorFound}'"
}

# ----------------------------------------------------------------------------------
# Display CSV Server list in a user friendly manner.
# This functoin was created to reduce the duplication on code when setting up replication.
# NOTE: Context of variable(s) is based on function exection context. 
#
# Parameters:
#  - ${1}: serverListCsv: csv string of servers to display
#  - ${2}: sectionDisplayHeading: String to display as section heading
# ----------------------------------------------------------------------------------
function displayServerListFromCsv() {
  local serverListCsv="${1}"
  local sectionDisplayHeading="${2}"
  IFS=',' read -ra arrServerList <<< "${serverListCsv}"
  # Note that format for statefulset pod service URL is {hostname}.{service-name}.{POD_NAMESPACE}.svc.cluster.local
  fqdnCount=${#arrServerList[@]}
  echo "${sectionDisplayHeading}"
  if [ "${fqdnCount}" -gt "0" ]; then
    for serverItem  in "${arrServerList[@]}"
    do
      echo "   > ${serverItem}"
      setupcommand=${setupcommand}$( echo --bootstrapReplicationServer "'${serverItem}'" \ )
      if [ "${#arrServerList[${i}]}" -le "5" ]; then
        echo "     [WARN] Server details appears to be too short"
      fi
    done
    echo "   NOTE: Atleast one Replication Server must be alive and working for replication to kick in"
    echo "   Expected format is {fqdn}:{replication-port}"
    echo ""
  else
    echo "-- WARN: No FQDN found in RS_LIST_INTER_CLUSTER string. Please check variable."
    echo "   Expected format '{global-fqdn}:{replication-port},{global-fqdn}:{replication-port}'"
    echo ""
  fi
}

# ----------------------------------------------------------------------------------
# Checks that the first intra cluster Replication Server (RS) in the list is alive
#
# Parameters:
#  - ${1}: selfReplicate: Allowed values 'true' or 'false'
#  - ${2}: serverListCsv_Intra: csv string of RS:PORT to validate
# ----------------------------------------------------------------------------------
function checkIntraRsIsAlive() {
  local selfReplicate="${1}"
  local serverListCsv_Intra="${2}"
  if [ "${selfReplicate,,}" == "false" ]; then
    # This section is only for non replication server components
    arrRsSvcList=($(echo "${serverListCsv_Intra}" | tr ',' '\n'))
    if [ -n  "${arrRsSvcList}" ]; then
      rsSvcListCount=${#arrRsSvcList[@]}
      if [ "${rsSvcListCount}" -gt 0 ]; then
        arrRsSvcToCheckProps=($(echo "${arrRsSvcList[0]}" | tr ':' '\n'))
        checkServerIsAlive --svc "${arrRsSvcToCheckProps[0]}" --channel "openssl" --port "${arrRsSvcToCheckProps[1]}"
      fi
    fi
  fi
}

# ----------------------------------------------------------------------------------
# Display Directory Server (DS) standard Environment Variabels
#
# Parameters:
#  - ${1}: Return Value: 'true' or 'false' if error was found
#  - ${2}: Type of DS. Allowed values 'rs', 'rs-aps', 'rs-ts', 'rs-us', 'aps', 'ts', 'us'
#  - ${3}: DS certificate alias
# ----------------------------------------------------------------------------------
function setupNewDS() {
  local errorFound="false"
  local dsType="${2}"
  local certAlias="${3}"
  local errorFound="false"
  [ ! -d "${path_tmpFolder}" ] && local path_tmpFolder="/tmp"
  local path_tmpScript="${path_tmpFolder}/setupDS.sh"
  local svcURL_curr="${HOSTNAME}.${POD_SERVICE_NAME}.${POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}" # Note that format for statefulset pod service URL is {hostname}.{service-name}.{POD_NAMESPACE}.svc.{CLUSTER_DOMAIN}
  local dsConfigOfflineMode="true"
  local svcURL_dest=""
  local returnVal=

  echo "========================================================="
  echo "Configuring a NEW Directory Server (DS) instance as '${dsType}'"
  echo "---------------------------------------------------------"
  echo ""

  prepareServerFolders # Must be executed before running first DS binary command on server
  optimizeJVMforPod

  [ -z "${dsType}" ] && echo "-- ERROR: dsType is Empty. Should be either 'rs', 'rs-aps', 'rs-ts', 'rs-us', 'aps', 'ts', or 'us'" && errorFound="true"
  [ -z "${certAlias}" ] && echo "-- ERROR: certAlias is Empty. Please provide a valid string." && errorFound="true"

  echo "-> Creating Setup command"
  local epocTime=$(date +%s)
  local serverId_with_epocTime="${HOSTNAME}_${epocTime}"
  echo "-- Current server service is ${svcURL_curr}"
  echo "-- Generated Server ID is ${serverId_with_epocTime}"
  echo "-- Creating installation command"
  local setupcommand=$( echo ${DS_APP}/setup \
    --adminConnectorPort ${PORT_ADMIN} \
    --deploymentKey "'${SECRET_DEPLOYMENT_KEY}'" \
    --deploymentKeyPassword "'${SECRET_PASSWORD_DEPLOYMENT_KEY}'" \
    --hostname "'${svcURL_curr}'" \
    --httpPort ${PORT_HTTP} --httpsPort ${PORT_HTTPS} \
    --instancePath "'${DS_INSTANCE}'" \
    --keyStorePassword "'${SECRET_PASSWORD_KEYSTORE}'" \
    --ldapPort ${PORT_LDAP} --ldapsPort ${PORT_LDAPS} \
    --monitorUserPassword "'${SECRET_PASSWORD_USER_MONITOR}'" \
    --rootUserDN "'${DN_ADMIN}'" \
    --rootUserPassword "'${SECRET_PASSWORD_USER_ADMIN}'" \
    --serverId "'${serverId_with_epocTime}'" \
    --usePkcs12keyStore "'${path_keystoreFile}'" \ )
  echo ""

  # Add custom profiles based on DS type
  # ------------------------------------
  case "${dsType,,}" in
    "rs"|"rs-aps"|"rs-ts"|"rs-us")
      setupcommand=${setupcommand}$( echo --certNickname "'${certAlias}'" \ )
      ;;
    "aps")
      setupcommand=${setupcommand}$( echo \
        --certNickname "'${certAlias}'" \
        --profile am-config \
        --set am-config/amConfigAdminPassword:${SECRET_PASSWORD_USER_AM} \
        --set am-config/backendName:cfgStore \
        --set am-config/baseDn:${DN_BASE} \ )
      ;;
    "ts")
      setupcommand=${setupcommand}$( echo \
        --certNickname "'${certAlias}'" \
        --profile am-cts \
        --set am-cts/amCtsAdminPassword:${SECRET_PASSWORD_USER_AM} \
        --set am-cts/backendName:tokenStore \
        --set am-cts/baseDn:${DN_BASE} \ )
      ;;
    "us")
      setupcommand=${setupcommand}$( echo --certNickname "'${certAlias}'" \
        --profile am-identity-store \
        --set am-identity-store/amIdentityStoreAdminPassword:${SECRET_PASSWORD_USER_AM} \
        --set am-identity-store/backendName:userStore \
        --set am-identity-store/baseDn:${DN_BASE} \ )

      if [ "${REPO_ADD_IDM}" == "true" ]; then
        if [ -n "${REPO_DOMAIN}" ]; then
          echo "-- Adding IDM Repo profile to command"
            setupcommand=${setupcommand}$( echo \
              --profile idm-repo \
              --set idm-repo/domain:${REPO_DOMAIN} \
              --set idm-repo/backendName:idmRepo \ )
        else
          echo ""
          echo "-- ERROR: Domain for IDM Repo is empty."
          echo "   User Store will NOT be setup with an IDM Repo."
          echo "   Please correct and try again."
          echo ""
        fi
      fi
      ;;
    *)
      echo "-- ERROR: Invalid DS type '${dsType}' provided. Allowed values are 'rs', 'rs-aps', 'rs-ts', 'rs-us', 'aps', 'ts', 'us'"
      errorFound="true"
      ;;
  esac

  # Setting up Local Replication
  if [ "${SELF_REPLICATE,,}" == "true" ] || $(echo "${dsType,,}" | grep -q "rs"); then
    setupcommand=${setupcommand}$( echo --replicationPort ${PORT_REPLICATION} \ )

    if [ "${SELF_REPLICATE,,}" == "true" ]; then
      echo "-- Self Replication has been requested. The Servers are:"
    else
      echo "-- Local Replication will be used. The Servers are:"
    fi

    for (( i=0; i<${REPLICAS}; i++ ))
    do
      tmpSvcURL="${POD_BASENAME}-${i}.${POD_SERVICE_NAME}.${POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}:${PORT_REPLICATION}"
      echo "   > ${tmpSvcURL}"
      setupcommand=${setupcommand}$( echo --bootstrapReplicationServer "'${tmpSvcURL}'" \ )
    done
    echo "   Expected format is {fqdn}:{replication-port}"
    echo ""
  elif [ "${SELF_REPLICATE,,}" == "false" ]; then
    # This section is only for non replication server components
    displayServerListFromCsv "${RS_LIST_INTRA_CLUSTER}" "-- Intra Cluster Replication has been requested. The Servers are:"
  fi

  # Setting up Inter Cluster Replication (RS only)
  if [ "${INTER_CLUSTER_REPL_ON,,}" == "true" ]; then
    displayServerListFromCsv "${RS_LIST_INTER_CLUSTER}" "-- Inter Cluster Replication has been requested. The Servers are:"
  fi

  if [ "${errorFound}" == "false" ]; then
    setupcommand=${setupcommand}$( echo --acceptLicense )
    echo "${setupcommand}" > "${path_tmpScript}"
    echo "-- Command setup complete"
    echo ""

    checkIntraRsIsAlive "${SELF_REPLICATE}" "${RS_LIST_INTRA_CLUSTER}" 

    echo "-> Executing setup command"
    bash "${path_tmpScript}"
    returnVal="$?"
    if [ ${returnVal} -ne 0 ]; then
      echo "-- ERROR: Something went wrong. Returned code was '${returnVal}'."
      errorFound="true"
    fi
    echo "-- Done"
    echo ""

    if [ "${errorFound}" == "false" ]; then
      setupCustomJavaProperties errorFound "${LOAD_CUSTOM_JAVA_PROPS}" "${DS_HOME}"
      allowTruststoreAccessByDS "${svcURL_curr}" "${PORT_ADMIN}" "${DN_ADMIN}" "${SECRET_PASSWORD_USER_ADMIN}" "${JAVA_CACERTS}" "${SECRET_PASSWORD_TRUSTSTORE}" "${dsConfigOfflineMode}"
      disableInsecureCommsDS "${DISABLE_INSECURE_COMMS}" "${svcURL_curr}" "${PORT_ADMIN}" "${DN_ADMIN}" "${SECRET_PASSWORD_USER_ADMIN}" "${dsConfigOfflineMode}"
      
      # Running selected functions based on DS Type 
      case "${dsType,,}" in
        "rs"  | "rs-aps" | "rs-ts" | "rs-us")
          configureReplicationThreshold "${PORT_ADMIN}" "${DN_ADMIN}" "${SECRET_PASSWORD_USER_ADMIN}" "${THRESHOLD_DISK_LOW}" "${THRESHOLD_DISK_FULL}" "${dsConfigOfflineMode}"
          ;;
        "aps" | "ts" | "us")
          if [ "${SELF_REPLICATE,,}" == "true" ]; then
            configureReplicationThreshold "${PORT_ADMIN}" "${DN_ADMIN}" "${SECRET_PASSWORD_USER_ADMIN}" "${THRESHOLD_DISK_LOW}" "${THRESHOLD_DISK_FULL}" "${dsConfigOfflineMode}"
          fi
          ;;
        *)
          echo "-- ERROR: Invalid DS type '${dsType}' provided. Allowed values are 'rs', 'rs-aps', 'rs-ts', 'rs-us', 'aps', 'ts', 'us'"
          errorFound="true"
          ;;
      esac
    fi
    if [ "${errorFound}" == "false" ]; then
      if [ "${LOG_MODE,,}" == "stdout" ]; then
        configureJSONStdoutLogs "${svcURL_curr}" ${PORT_ADMIN} "${DN_ADMIN}" "${SECRET_PASSWORD_USER_ADMIN}"
      fi
      loadDsSchema "${LOAD_SCHEMA,,}"
  
      { # Run in background while DS is starting up
        checkDSisHealthy errorFound "${svcURL_curr}" "${PROTOCOL_REST}" "${PORT_REST}";
        if [ "${errorFound}" == "false" ]; then
          if [ "${BACKUP_BACKEND,,}" == "true" ]; then
            scheduleDsBackendsBackup "${BACKUP_FREQUENCY}" "${PORT_ADMIN}" "${DN_ADMIN}" "${SECRET_PASSWORD_USER_ADMIN}" "${NOTIFICATION_EMAIL}";
          fi
          getReplicationStatus "${svcURL_curr}" "${SECRET_PASSWORD_USER_ADMIN}" "${PORT_ADMIN}" "${DN_ADMIN}";
          podIndx=$(echo "${HOSTNAME}" | grep -Eo '[0-9]+$');
          if [ "${dsType,,}" == "aps" ] && [ "${podIndx}" -eq "0" ]; then
            # App Policy Store only
            echo "-> Loading up Access Manager File Based Config (FBC) additional schema";
            # Source: https://github.com/ForgeRock/forgeops/blob/master/docker/ds/scripts/external-am-datastore.ldif
            #         https://github.com/ForgeRock/forgeops/blob/master/docker/ds/ds-new/default-scripts/setup
            path_tmp01="${DS_CUSTOM_SCHEMA}";
            if [ -f "${path_tmp01}" ]; then
              ${DS_APP}/bin/ldapmodify --hostname "${svcURL_curr}" --continueOnError \
                --bindDN "${DN_ADMIN}" --bindPassword "${SECRET_PASSWORD_USER_ADMIN}" \
                --port ${PORT_LDAPS} --useSsl --TrustAll -f "${path_tmp01}";
            else
              echo "-- WARN: '${path_tmp01}' NOT found. Skipping ...";
            fi
            echo "-- Done";
            echo "";
          fi
          executeDsConfigScript "${LOAD_CUSTOM_DS_CONFIG,,}" "${PROTOCOL_REST}" "${PORT_REST}"; 
          echo "-- INFO: Setup process completed successfully";
          echo "";
        fi
      } &     
    fi
  fi
  eval "${1}='${errorFound}'"
}