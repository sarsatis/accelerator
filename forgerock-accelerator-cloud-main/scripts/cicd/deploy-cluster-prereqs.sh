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

# This file contains scripts to deploy the Kubernetes Cluster prerequisites
# required by the Midships ForgeRock Cloud Accelerator.

function checkForBashError() {
  if [ "${1}" -ne 0 ]; then
      echo "-- ERROR: Something went wrong. See above logs. Returned '${1}'. Exiting ..."
      exit 1;
  fi
}

echo "============================================================="
echo ">>  DEPLOYING FORGEROCK KUBERNETES CLUSTER PRE-REQUISITES  <<"
echo "============================================================="
echo " "
errorFound="false"
envType="${ENV_TYPE:-dev}"
namespace="${NAMESPACE:-forgerock}"
path_kubeconfig="$HOME/.kube/config"


if [ ! -f "${path_kubeconfig}" ]; then
  echo "-- ERROR: '${path_kubeconfig}' not found."
  errorFound="true"
fi

if [ -z "${namespace}" ]; then
  echo "-- ERROR: namespace is empty."
  errorFound="true"
fi
echo "-- Done"
echo " "

echo "-> Display variables"
echo "envType: '${envType}'"
echo "namespace: '${namespace}'"
echo "path_kubeconfig: '${path_kubeconfig}'"
echo "-- Done"
echo " "

if [ "${errorFound}" == "false" ]; then
  if [ "$(kubectl --kubeconfig=${path_kubeconfig} get ns | grep "${namespace}" | wc -l)" -eq 0 ]; then
    echo "-> Creating Namespace"
    kubectl --kubeconfig "${path_kubeconfig}" create ns "${namespace}"
    checkForBashError "$?"
    echo "-- Done"
    echo " "
  fi
fi

if [ "${errorFound}" == "true" ]; then
  echo "-- ERROR: Something went wrong. See above log for details. Exiting ..."
  exit 1
fi