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

# This file contains scripts to deploy the Kubernetes Secrets and Configmaps
# required by the Midships ForgeRock Cloud Accelerator.

function checkForBashError() {
  if [ "${1}" -ne 0 ]; then
      echo "-- ERROR: Something went wrong. See above logs. Returned '${1}'. Exiting ..."
      exit 1;
  fi
}

echo "=========================================================="
echo ">>  DEPLOYING FORGEROCK COMPONENTS SECRETS AND CONFIGS  <<"
echo "=========================================================="
echo " "
errorFound="false"
envType="${ENV_TYPE:-dev}"
envType="${envType}-$(date)"
namespace="${NAMESPACE:-forgerock}"
clusterId="dc${CLUSTER_ID:-1}"
deployConfigMaps="${1:-true}"
deploySecrets="${2:-true}"
local_helm_config=""
clusterId2=
#Container Registry
gcpServiceKey="${GCP_SERVICE_KEY}"
imagePullSecrets="${IMAGE_PULL_SECRETS:-fr-nexus-docker}"
path_gcp_registry_admin="/tmp/gcp-docker-registry-admin.json"
path_kubeconfig="${PATH_KUBECONFIG:-$HOME/.kube/config}"

[ "${clusterId}" == "dc1" ] && clusterId2="dc2"
[ "${clusterId}" == "dc2" ] && clusterId2="dc1"

echo "-> Display variables"
echo "envType: '${envType}'"
echo "clusterId: '${clusterId}'"
echo "clusterId2: '${clusterId2}'"
echo "namespace: '${namespace}'"
echo "imagePullSecrets: '${imagePullSecrets}'"
echo "path_kubeconfig: '${path_kubeconfig}'"
echo "path_gcp_registry_admin: '${path_gcp_registry_admin}'"
echo "deployConfigMaps: ${deployConfigMaps}"
echo "deploySecrets: ${deploySecrets}"
echo "-- Done"
echo " "

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

if [[ "${CI_REGISTRY_URL}" == *"local"* ]]; then
  local_helm_config="--values ./deploy/helm/configs/environment-config/values-local-dev-overrides.yaml"
fi
if [ "${errorFound}" == "false" ]; then
  if [ "${deployConfigMaps}" == "true" ]; then
    echo "-> Helm Unit Tests for Configmaps"
#    helm unittest deploy/helm/configs/charts/am
#    helm unittest deploy/helm/configs/charts/ds
#    helm unittest deploy/helm/configs/charts/idm
#    helm unittest deploy/helm/configs/charts/ig
    echo "-> Updating K8s Config Maps"
    helm upgrade --install --wait --timeout 0m20s \
      $local_helm_config --set global.clusterId="${clusterId}" \
      --set global.clusterId2="${clusterId2}" \
      --set global.envType="${envType}" \
      --set global.namespace="${namespace}" \
      --namespace "${namespace}" \
      configmaps-forgerock-all deploy/helm/configs/
    checkForBashError "$?"
    echo "-- Done"
    echo " "
  fi

  if [ "${deploySecrets}" == "true" ]; then

    if [ "${errorFound}" == "false" ]; then
      # Cannot update secrets. They need to be removed and recreated.
      chmod 770 scripts/cicd/remove-all.sh
      scripts/cicd/remove-all.sh "secrets"
      echo "--> Helm Unit Tests for Secrets"
#      helm unittest deploy/helm/secrets
      echo "-> Updating K8s Secrets"
      helm upgrade --install --wait --timeout 0m20s \
        --set global.clusterId="${clusterId}" \
        --set global.clusterId2="${clusterId2}" \
        --set global.envType="${envType}" \
        --set global.namespace="${namespace}" \
        --namespace "${namespace}" \
        --kubeconfig "${path_kubeconfig}" \
        secrets-forgerock-all deploy/helm/secrets/
      checkForBashError "$?"
      echo "-- Done"
      echo " "

      if [ -n "${gcpServiceKey}" ]; then
        echo ${gcpServiceKey} | base64 -d > ${path_gcp_registry_admin}
        echo "$(kubectl config current-context)"

        if [ "$(kubectl --kubeconfig "${path_kubeconfig}" get secret ${imagePullSecrets} --namespace "${namespace}" 2>/dev/null | grep "${imagePullSecrets}" | wc -l)" -gt 0 ]; then
          echo "-> Deleting GCP Image Pull Secret"
          kubectl --kubeconfig "${path_kubeconfig}" delete secret "${imagePullSecrets}" --namespace "${namespace}"
          checkForBashError "$?"
          echo "-- Done"
          echo " "
        fi

        echo "-> Creating GCP Image Pull Secret"
        kubectl --kubeconfig "${path_kubeconfig}" create secret docker-registry "${imagePullSecrets}" \
          --docker-server=gcr.io --docker-username=_json_key --docker-email=taweh@midships.io \
          --docker-password="$(cat ${path_gcp_registry_admin})" --namespace "${namespace}"
        checkForBashError "$?"
        echo "-- Done"
        echo " "
      elif [[ "${CI_REGISTRY_URL}" == *"local"* ]]; then
        echo "-- Image Pull Secrets not needed for local registry"
      else
        echo "-- ERROR: gcpServiceKey is empty."
        errorFound="true"
      fi
    fi
  fi
fi

if [ "${errorFound}" == "true" ]; then
  echo "-- ERROR: Something went wrong. See above log for details. Exiting ..."
  exit 1
fi