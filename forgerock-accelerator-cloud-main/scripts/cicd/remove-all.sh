#!/usr/bin/env bash
# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

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

# This file contains scripts to remove the Midships ForgeRock Cloud Accelerator
# ForgeRock components 
source ~/.bashrc

function checkForBashError() {
  if [ "${1}" -ne 0 ]; then
      echo "-- ERROR: Something went wrong. See above logs. Returned '${1}'. Exiting ..."
      exit 1;
  fi
}

echo "[ REMOVE COMPONENTS ]"
echo " "

echo "-> Setting variables"
clusterID="dc${CLUSTER_ID:-1}"
namespace="${NAMESPACE:-forgerock}"
podNameAM="${PODNAME_AM:-forgerock-access-manager}-${clusterID}"
[ -n "${PODNAME_AM_GREEN}" ] && podNameAmGreen="${PODNAME_AM_GREEN}-${clusterID}"
podNameAPS="${PODNAME_APS:-forgerock-app-policy-store}-${clusterID}"
podNameRS="${PODNAME_RS:-forgerock-repl-server}-${clusterID}"
podNameRS_APS="${PODNAME_RS:-forgerock-repl-server}-aps-${clusterID}"
podNameRS_US="${PODNAME_RS:-forgerock-repl-server}-us-${clusterID}"
podNameRS_TS="${PODNAME_RS:-forgerock-repl-server}-ts-${clusterID}"
podNameUS="${PODNAME_US:-forgerock-user-store}-${clusterID}"
podNameTS="${PODNAME_TS:-forgerock-token-store}-${clusterID}"
podNameIDM="${PODNAME_IDM:-forgerock-idm}-${clusterID}"
podNameIG="${PODNAME_IG:-forgerock-ig}-${clusterID}"
path_kubeconfig="${HOME}/.kube/config"
echo "-- Done"
echo " "

echo "-> Variables"
echo "clusterID: ${clusterID}"
echo "namespace: ${namespace}"
echo "podNameAM: ${podNameAM}"
echo "podNameAmGreen: ${podNameAmGreen}"
echo "podNameAPS: ${podNameAPS}"
echo "podNameRS_APS: ${podNameRS_APS}"
echo "podNameRS_US: ${podNameRS_US}"
echo "podNameRS_TS: ${podNameRS_TS}"
echo "podNameUS: ${podNameUS}"
echo "podNameTS: ${podNameTS}"
echo "podNameIDM: ${podNameIDM}"
echo "podNameIG: ${podNameIG}"
echo "-- Done"
echo " "

function removeAll(){
  echo " -------------------"
  echo "| REMOVE EVERYTHING |"
  echo " -------------------"
  echo "{1} is set to '${1}'. Allowed values 'all' and 'all-skip-ns'."
  echo " "

  if [ "${1}" == "all-skip-ns" ]; then
    echo "-> Uninstalling components installed by Helm"
    echo "   Components: (sts,secrets,configmaps,svc)"
    [ "$(helm ls --all --short --kubeconfig "${path_kubeconfig}" --namespace "${NAMESPACE}" | wc -l)" -gt 1 ] && helm ls --all --short  --kubeconfig "${path_kubeconfig}" --namespace "${NAMESPACE}" | xargs helm uninstall --kubeconfig "${path_kubeconfig}" --namespace "${NAMESPACE}"
    echo "-- Done"
    echo " "

    echo "-> Removing all PVC"
    echo "   (PV are not tied to namespace and with DELETE 'Reclaim Policy' will deleted with PVC)"
    kubectl delete pvc --all --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${NAMESPACE}"
    echo "-- Waiting 15 seconds for SVC to finish clearing up ..."
    sleep 15
    echo "-- Done"
    echo " "
  fi

  if [ "${1}" == "all" ]; then
    echo "-> Removing namespace '${NAMESPACE}' "
    kubectl delete ns "${NAMESPACE}"
    echo "-- Done"
    echo " "
  fi
}

function removeForgeRockApplications() {
  REMOVE_APP_AM="${REMOVE_APP_AM:-true}"
  REMOVE_APP_APS="${REMOVE_APP_APS:-true}"
  REMOVE_APP_US="${REMOVE_APP_US:-true}"
  REMOVE_APP_TS="${REMOVE_APP_TS:-true}"
  REMOVE_APP_IDM="${REMOVE_APP_IDM:-true}"
  REMOVE_APP_IG="${REMOVE_APP_IG:-true}"
  REMOVE_APP_RS="${REMOVE_APP_RS:-true}"
  REMOVE_APP_RS_APS="${REMOVE_APP_RS_APS:-true}"
  REMOVE_APP_RS_US="${REMOVE_APP_RS_US:-true}"
  REMOVE_APP_RS_TS="${REMOVE_APP_RS_TS:-true}"

  echo " -------------------------------"
  echo "| REMOVE FORGEROCK APPLICATIONS |"
  echo " -------------------------------"
  echo "REMOVE_APP_AM: ${REMOVE_APP_AM}"
  echo "REMOVE_APP_APS: ${REMOVE_APP_APS}"
  echo "REMOVE_APP_US: ${REMOVE_APP_US}"
  echo "REMOVE_APP_TS: ${REMOVE_APP_TS}"
  echo "REMOVE_APP_IDM: ${REMOVE_APP_IDM}"
  echo "REMOVE_APP_IG: ${REMOVE_APP_IG}"
  echo "REMOVE_APP_RS: ${REMOVE_APP_RS}"
  echo "REMOVE_APP_RS_APS: ${REMOVE_APP_RS_APS}"
  echo "REMOVE_APP_RS_US: ${REMOVE_APP_RS_US}"
  echo "REMOVE_APP_RS_TS: ${REMOVE_APP_RS_TS}"
  echo " "

  if [ "${REMOVE_APP_RS}" == "true" ]; then
    echo "-> Unstalling all Replication Servers (if deployed under single helm chart)"
    helm uninstall "${podNameRS}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}" 
    echo "-- Done"
    echo " "
  fi

  if [ "${REMOVE_APP_RS_APS}" == "true" ]; then
    echo "-> Unstalling Replication Server (for App-Policy Store)"
    helm uninstall "${podNameRS_APS}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}" 
    kubectl delete sts "${podNameRS_APS}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}" 
    echo "-- Done"
    echo " "
  fi

  if [ "${REMOVE_APP_RS_US}" == "true" ]; then
    echo "-> Uninstalling Replication Server (for User Store)"
    helm uninstall "${podNameRS_US}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    kubectl delete sts "${podNameRS_US}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}" 
    echo "-- Done"
    echo " "
  fi

  if [ "${REMOVE_APP_RS_TS}" == "true" ]; then
    echo "-> Uninstalling Replication Server (for Token Store)"
    helm uninstall "${podNameRS_TS}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    kubectl delete sts "${podNameRS_TS}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}" 
    echo "-- Done"
    echo " "
  fi

  if [ "${REMOVE_APP_APS}" == "true" ]; then
    echo "-> Uninstalling Application and Policy Store"
    helm uninstall "${podNameAPS}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    echo "-- Done"
    echo " "
  fi

  if [ "${REMOVE_APP_TS}" == "true" ]; then
    echo "-> Uninstalling Token Store"
    helm uninstall "${podNameTS}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    echo "-- Done"
    echo " "
  fi

  if [ "${REMOVE_APP_US}" == "true" ]; then
    echo "-> Uninstalling User Store"
    helm uninstall "${podNameUS}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    echo "-- Done"
    echo " "
  fi

  if [ "${REMOVE_APP_AM}" == "true" ]; then
    echo "-> Uninstalling Access Manager"
    helm uninstall "${podNameAM}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    echo "-- Done"
    echo " "

    if [ -n "${PODNAME_AM_GREEN}" ]; then
      echo "-> Uninstalling Access Manager Green"
      helm uninstall "${podNameAmGreen}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
      echo "-- Done"
      echo " "
    fi
  fi

  if [ "${REMOVE_APP_IDM}" == "true" ]; then
    echo "-> Uninstalling IDM"
    helm uninstall "${podNameIDM}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    echo "-- Done"
    echo " "
  fi

  if [ "${REMOVE_APP_IG}" == "true" ]; then
    echo "-> Uninstalling IG"
    helm uninstall "${podNameIG}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    echo "-- Done"
    echo " "
  fi

  # Remove PVCs
  if [ "${REMOVE_APP_RS_APS}" == "true" ]; then
    echo "-> Removing all PVC - Replication Server App-Policy Store "
    echo "   (PV are not tied to namespace and with DELETE 'Reclaim Policy' will deleted with PVC)"
    kubectl delete pvc "pvc-${podNameRS_APS}-0" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    kubectl delete pvc "pvc-${podNameRS_APS}-1" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    kubectl delete pvc "pvc-${podNameRS_APS}-2" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    echo "-- Done"
    echo " "
  fi

  if [ "${REMOVE_APP_RS_US}" == "true" ]; then
  echo "-> Removing all PVC - Replication Server User Store "
  echo "   (PV are not tied to namespace and with DELETE 'Reclaim Policy' will deleted with PVC)"
  kubectl delete pvc "pvc-${podNameRS_US}-0" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
  kubectl delete pvc "pvc-${podNameRS_US}-1" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
  kubectl delete pvc "pvc-${podNameRS_US}-2" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
  echo "-- Done"
  echo " "
  fi
  if [ "${REMOVE_APP_RS_TS}" == "true" ]; then
    echo "-> Removing all PVC - Replication Server Token Store "
    echo "   (PV are not tied to namespace and with DELETE 'Reclaim Policy' will deleted with PVC)"
    kubectl delete pvc "pvc-${podNameRS_TS}-0" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    kubectl delete pvc "pvc-${podNameRS_TS}-1" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    kubectl delete pvc "pvc-${podNameRS_TS}-2" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    echo "-- Done"
    echo " "
  fi

  if [ "${REMOVE_APP_APS}" == "true" ]; then
    echo "-> Removing all PVC - App Policy Store "
    echo "   (PV are not tied to namespace and with DELETE 'Reclaim Policy' will deleted with PVC)"
    kubectl delete pvc "pvc-${podNameAPS}-0" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    kubectl delete pvc "pvc-${podNameAPS}-1" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    kubectl delete pvc "pvc-${podNameAPS}-2" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    echo "-- Done"
    echo " "
  fi

  if [ "${REMOVE_APP_TS}" == "true" ]; then
    echo "-> Removing all PVC - Token Store "
    echo "   (PV are not tied to namespace and with DELETE 'Reclaim Policy' will deleted with PVC)"
    kubectl delete pvc "pvc-${podNameTS}-0" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    kubectl delete pvc "pvc-${podNameTS}-1" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    kubectl delete pvc "pvc-${podNameTS}-2" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    echo "-- Done"
    echo " "
  fi

  if [ "${REMOVE_APP_US}" == "true" ]; then
    echo "-> Removing all PVC - User Store "
    echo "   (PV are not tied to namespace and with DELETE 'Reclaim Policy' will deleted with PVC)"
    kubectl delete pvc "pvc-${podNameUS}-0" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    kubectl delete pvc "pvc-${podNameUS}-1" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    kubectl delete pvc "pvc-${podNameUS}-2" --force --grace-period=0 --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    echo "-- Done"
    echo " "
  fi
}

function removeServices() {
  echo " ---------------------------"
  echo "| REMOVE FORGEROCK SERVICES |"
  echo " ---------------------------"
  echo " "

  echo "-> Uninstallin Replication Server (RS) Service(s)"
  helm uninstall "svc-${podNameRS}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}" 
  echo "-- Done"
  echo " "

  echo "-> Uninstallin Replication Server (RS) Service(s) for Applicaiton Policy Store"
  helm uninstall "svc-${podNameRS_APS}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}" 
  echo "-- Done"
  echo " "

  echo "-> Uninstallin Replication Server (RS) Service(s) for Token Store"
  helm uninstall "svc-${podNameRS_TS}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
  echo "-- Done"
  echo " "

  echo "-> Uninstallin Replication Server (RS) Service(s) for User Store"
  helm uninstall "svc-${podNameRS_US}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
  echo "-- Done"
  echo " "

  echo "-> Uninstallin User Store (US) Service(s)"
  helm uninstall "svc-${podNameUS}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
  echo "-- Done"
  echo " "

  echo "-> Uninstallin Token Store (TS) Service(s)"
  helm uninstall "svc-${podNameTS}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
  echo "-- Done"
  echo " "

  echo "-> Uninstallin Application Policy Store (APS) Service(s)"
  helm uninstall "svc-${podNameAPS}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
  echo "-- Done"
  echo " "

  echo "-> Uninstallin Access Manager (AM) Service(s)"
  helm uninstall "svc-${podNameAM}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
  echo "-- Done"
  echo " "

  echo "-> Uninstallin Identity Manager (IDM) Service(s)"
  helm uninstall "svc-${podNameIDM}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
  echo "-- Done"
  echo " "

  echo "-> Uninstallin Identity Gateway (IG) Service(s)"
  helm uninstall "svc-${podNameIG}" --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
  echo "-- Done"
  echo " "
}

function removeSecrets() {
  echo " --------------------------"
  echo "| REMOVE FORGEROCK SECRETS |"
  echo " --------------------------"
  echo " "
  errorFound="false"
  #Container Registry
  namespace="${NAMESPACE:-forgerock}"
  imagePullSecrets="${IMAGE_PULL_SECRETS:-fr-nexus-docker}"

  echo "-> Verifying key variables"
  if [ ! -f "${path_kubeconfig}" ]; then
    echo "-- ERROR: '${path_kubeconfig}' not found."
    errorFound="true"
  fi

  if [ -z "${imagePullSecrets}" ]; then
    echo "-- ERROR: imagePullSecrets is empty."
    errorFound="true"
  fi
  echo "-- Done"
  echo " "

  
  if [ "${errorFound}" == "false" ]; then
    echo "-> Display variables"
    echo "namespace: '${namespace}'"
    echo "imagePullSecrets: '${imagePullSecrets}'"
    echo "path_kubeconfig: '${path_kubeconfig}'"
    echo "-- Done"
    echo " "

    helm uninstall secrets-forgerock-all --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
    echo "-- Done"
    echo " "

    if [ "$(kubectl --kubeconfig "${path_kubeconfig}" get secret ${imagePullSecrets} --namespace "${namespace}" 2> /dev/null | grep "${imagePullSecrets}" | wc -l)" -gt 0 ]; then
      echo "-> Deleting Image Pull Secret"
      kubectl --kubeconfig "${path_kubeconfig}" delete secret "${imagePullSecrets}" --namespace "${namespace}"
      checkForBashError "$?"
      echo "-- Done"
      echo " "
    fi
  fi

  if [ "${errorFound}" == "true" ]; then
    echo "-- ERROR: Something went wrong. See above log for details. Exiting ..."
    exit 1
  fi
}

function removeConfigMaps() {
  echo " -----------------------------"
  echo "| REMOVE FORGEROCK CONFIGMAPS |"
  echo " -----------------------------"
  echo " "
  helm uninstall configmaps-forgerock-all --kubeconfig "${path_kubeconfig}" --namespace "${namespace}"
  echo "-- Done"
  echo " "
}

case "${1}" in
  "all")
    removeAll "${1}"
    ;;
  "all-skip-ns")
    removeAll "${1}"
    ;;
  "apps")
    removeForgeRockApplications
    ;;
  "svc")
    removeServices 
    ;;
  "secrets-configs")
    removeSecrets
    removeConfigMaps
    ;;
  "secrets")
    removeSecrets
    ;;
  "configs")
    removeConfigMaps
    ;;
  *)
    echo "-- ERROR: Invalid input '${1}' provided. Allowed are 'apps', 'svc', 'secrets', 'configs'"
    ;;
esac