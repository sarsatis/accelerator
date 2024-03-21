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

# This file contains scripts to deploy the ForgeRock components Kubernetes 
# Services required by the Midships ForgeRock Cloud Accelerator.

function checkForBashError() {
  if [ "${1}" -ne 0 ]; then
      echo "-- ERROR: Something went wrong. See above logs. Returned '${1}'. Exiting ..."
      exit 1;
  fi
}

echo "====================================="
echo ">>  DEPLOYING FORGEROCK SERVVICES  <<"
echo "====================================="
echo
source ~/.bashrc
k8sLocation="${K8S_LOCATION:-'gcp'}"
envType="${ENV_TYPE:-dev}"; envType="${envType}-$(date)"
namespace="${NAMESPACE:-'forgerock'}"
clusterId="dc${CLUSTER_ID:-1}"

# Setting initial Pod names
podNameAM="${PODNAME_AM:-forgerock-access-manager}"
podNameAPS="${PODNAME_APS:-forgerock-app-policy-store}"
podNameIDM="${PODNAME_IDM:-forgerock-idm}"
podNameIG="${PODNAME_IG:-forgerock-ig}"
podNameRS="${PODNAME_RS:-forgerock-repl-server}"
podNameTS="${PODNAME_TS:-forgerock-token-store}"
podNameUS="${PODNAME_US:-forgerock-user-store}"

# Updating Pod names based on cluster
podNameAM="${podNameAM}-${clusterId}"
podNameAPS="${podNameAPS}-${clusterId}"
podNameIDM="${podNameIDM}-${clusterId}"
podNameIG="${podNameIG}-${clusterId}"
podNameRS_APS="${podNameRS}-aps-${clusterId}"
podNameRS_TS="${podNameRS}-ts-${clusterId}"
podNameRS_US="${podNameRS}-us-${clusterId}"
podNameRS="${podNameRS}-${clusterId}"
podNameTS="${podNameTS}-${clusterId}"
podNameUS="${podNameUS}-${clusterId}"
echo " "
if [[ ${CI_REGISTRY_URL} == *"local"* ]]; then
  k8sLocation="${CI_REGISTRY_URL}"
fi

if [ "${k8sLocation}" == "gcp" ]; then
  if [ "${clusterId}" == "dc1" ]; then
    echo "-- Setting Local Cluster Service IPs"
    svc_ip_rs0_us="34.138.158.174"
    svc_ip_rs1_us="35.227.82.242"
    svc_ip_rs2_us=
    svc_ip_rs0_ts="35.237.189.160"
    svc_ip_rs1_ts="34.23.177.69"
    svc_ip_rs2_ts=
    svc_ip_rs0_aps="34.138.94.34"
    svc_ip_rs1_aps="35.185.100.251"
    svc_ip_rs2_aps=
    svc_ip_us0="34.73.197.166"
    svc_ip_us1="35.229.22.163"
    svc_ip_us2=
    svc_ip_ts0="34.75.12.230"
    svc_ip_ts1="34.23.144.62"
    svc_ip_ts2=
    svc_ip_aps0="35.229.118.8"
    svc_ip_aps1="34.138.113.120"
    svc_ip_aps2=
    echo "-- Setting 2nd Cluster Service IPs"
    hostAlias_ip_rs0_us="35.240.94.204"
    hostAlias_ip_rs1_us="35.195.187.191"
    hostAlias_ip_rs2_us=
    hostAlias_ip_rs0_ts="35.189.244.206"
    hostAlias_ip_rs1_ts="34.140.49.85"
    hostAlias_ip_rs2_ts=
    hostAlias_ip_rs0_aps="146.148.11.141"
    hostAlias_ip_rs1_aps="35.185.100.251"
    hostAlias_ip_rs2_aps=
    hostAlias_ip_us0="34.76.84.155"
    hostAlias_ip_us1="34.78.64.78"
    hostAlias_ip_us2=""
    hostAlias_ip_ts0="35.187.28.215"
    hostAlias_ip_ts1="34.77.69.106"
    hostAlias_ip_ts2=""
    hostAlias_ip_aps0="34.76.132.112"
    hostAlias_ip_aps1="34.138.113.120"
    hostAlias_ip_aps2=""
    clusterID2="dc2"
  elif [ "${clusterId}" == "dc2" ]; then
    echo "-- Setting Local Cluster Service IPs"
    svc_ip_rs0_us="35.240.94.204"
    svc_ip_rs1_us="35.195.187.191"
    svc_ip_rs2_us=
    svc_ip_rs0_ts="35.189.244.206"
    svc_ip_rs1_ts="34.140.49.85"
    svc_ip_rs2_ts=
    svc_ip_rs0_aps="146.148.11.141"
    svc_ip_rs1_aps="35.185.100.251"
    svc_ip_rs2_aps=
    svc_ip_us0="34.76.84.155"
    svc_ip_us1="34.78.64.78"
    svc_ip_us2=""
    svc_ip_ts0="35.187.28.215"
    svc_ip_ts1="34.77.69.106"
    svc_ip_ts2=""
    svc_ip_aps0="34.76.132.112"
    svc_ip_aps1="34.38.16.125"
    svc_ip_aps2=""
    echo "-- Setting 2nd Cluster Service IPs"
    hostAlias_ip_rs0_us="34.138.158.174"
    hostAlias_ip_rs1_us="35.227.82.242"
    hostAlias_ip_rs2_us=
    hostAlias_ip_rs0_ts="35.237.189.160"
    hostAlias_ip_rs1_ts="34.23.177.69"
    hostAlias_ip_rs2_ts=
    hostAlias_ip_rs0_aps="34.138.94.34"
    hostAlias_ip_rs1_aps="35.185.100.251"
    hostAlias_ip_rs2_aps=
    hostAlias_ip_us0="34.73.197.166"
    hostAlias_ip_us1="35.229.22.163"
    hostAlias_ip_us2=
    hostAlias_ip_ts0="34.75.12.230"
    hostAlias_ip_ts1="34.23.144.62"
    hostAlias_ip_ts2=
    hostAlias_ip_aps0="35.229.118.8"
    hostAlias_ip_aps1="34.38.16.125"
    hostAlias_ip_aps2=
    clusterID2="dc1"
  fi
fi

echo "Variables"
echo "---------"
echo "k8sLocation is ${k8sLocation}"
echo "envType is ${envType}"
echo "namespace is ${namespace}"
echo "clusterId is ${clusterId}"
echo " "
echo "podNameAM is ${podNameAM}"
echo "podNameAPS is ${podNameAPS}"
echo "podNameRS is ${podNameRS}"
echo "podNameRS_APS is ${podNameRS_APS}"
echo "podNameRS_US is ${podNameRS_US}"
echo "podNameRS_TS is ${podNameRS_TS}"
echo "podNameUS is ${podNameUS}"
echo "podNameTS is ${podNameTS}"
echo "podNameIDM is ${podNameIDM}"
echo "podNameIG is ${podNameIG}"
echo " "
echo "This Cluster Replication IPs"
echo "  > svc_ip_rs0_us: ${svc_ip_rs0_us}"
echo "  > svc_ip_rs1_us: ${svc_ip_rs1_us}"
echo "  > svc_ip_rs2_us: ${svc_ip_rs2_us}"
echo "  > svc_ip_rs0_ts: ${svc_ip_rs0_ts}"
echo "  > svc_ip_rs1_ts: ${svc_ip_rs1_ts}"
echo "  > svc_ip_rs2_ts: ${svc_ip_rs2_ts}"
echo "  > svc_ip_rs0_aps: ${svc_ip_rs0_aps}"
echo "  > svc_ip_rs1_aps: ${svc_ip_rs1_aps}"
echo "  > svc_ip_rs2_aps: ${svc_ip_rs2_aps}"
echo "  > svc_ip_us0: ${svc_ip_us0}"
echo "  > svc_ip_us1: ${svc_ip_us1}"
echo "  > svc_ip_us2: ${svc_ip_us2}"
echo "  > svc_ip_ts0: ${svc_ip_ts0}"
echo "  > svc_ip_ts1: ${svc_ip_ts1}"
echo "  > svc_ip_ts2: ${svc_ip_ts2}"
echo "  > svc_ip_aps0: ${svc_ip_aps0}"
echo "  > svc_ip_ap1: ${svc_ip_aps1}"
echo "  > svc_ip_aps2: ${svc_ip_aps2}"
echo " "

echo "-> Helm Unit Test for RS SVC's"
helm unittest deploy/helm/services/charts/repl-server
echo "-> Installing Replication Server (RS) Service(s) for User, Token amd Applicaiton Policy Store"
helm upgrade --install \
  --values ./deploy/helm/services/values.yaml \
  --set global.clusterId="${clusterId}" \
  --set global.namespace="${namespace}" \
  --set replserver.aps.svc_ip1="${svc_ip_rs0_aps}" \
  --set replserver.aps.svc_ip2="${svc_ip_rs1_aps}" \
  --set replserver.aps.svc_ip3="${svc_ip_rs2_aps}" \
  --set replserver.ts.svc_ip1="${svc_ip_rs0_ts}" \
  --set replserver.ts.svc_ip2="${svc_ip_rs1_ts}" \
  --set replserver.ts.svc_ip3="${svc_ip_rs2_ts}" \
  --set replserver.us.svc_ip1="${svc_ip_rs0_us}" \
  --set replserver.us.svc_ip2="${svc_ip_rs1_us}" \
  --set replserver.us.svc_ip3="${svc_ip_rs2_us}" \
  --namespace "${namespace}" \
  "svc-${podNameRS}" "deploy/helm/services/charts/repl-server/"
checkForBashError "$?"
echo "-- Done"
echo " "
echo "-> Helm Unit Test for US SVC"
helm unittest deploy/helm/services/charts/user-store
echo "-> Installing User Store (US) Service(s)"
helm upgrade --install \
  --values ./deploy/helm/services/values.yaml \
  --set global.clusterId="${clusterId}" \
  --set global.namespace="${namespace}" \
  --set userstore.svc_ip1="${svc_ip_us0}" \
  --set userstore.svc_ip2="${svc_ip_us1}" \
  --set userstore.svc_ip3="${svc_ip_us2}" \
  --namespace "${namespace}" \
  "svc-${podNameUS}" "deploy/helm/services/charts/user-store/"
checkForBashError "$?"
echo "-- Done"
echo " "
echo "-> Helm Unit Test for TS SVC"
helm unittest deploy/helm/services/charts/token-store
echo "-> Installing Token Store (TS) Service(s)"
helm upgrade --install \
  --values ./deploy/helm/services/values.yaml \
  --set global.clusterId="${clusterId}" \
  --set global.namespace="${namespace}" \
  --set tokenstore.svc_ip1="${svc_ip_ts0}" \
  --set tokenstore.svc_ip2="${svc_ip_ts1}" \
  --set tokenstore.svc_ip3="${svc_ip_ts2}" \
  --namespace "${namespace}" \
  "svc-${podNameTS}" "deploy/helm/services/charts/token-store/"
checkForBashError "$?"
echo "-- Done"
echo " "
echo "-> Helm Unit Test for APS SVC"
helm unittest deploy/helm/services/charts/app-policy-store
echo "-> Installing Application Policy Store (APS) Service(s)"
helm upgrade --install \
  --values ./deploy/helm/services/values.yaml \
  --set global.clusterId="${clusterId}" \
  --set global.namespace="${namespace}" \
  --set aps.svc_ip1="${svc_ip_aps0}" \
  --set aps.svc_ip2="${svc_ip_aps1}" \
  --set aps.svc_ip3="${svc_ip_aps2}" \
  --namespace "${namespace}" \
  "svc-${podNameAPS}" "deploy/helm/services/charts/app-policy-store/"
checkForBashError "$?"
echo "-- Done"
echo " "

echo "-> Helm Unit Test for AM SVC"
helm unittest deploy/helm/services/charts/access-manager
echo "-> Installing Access Manager (AM) Service(s)"
helm upgrade --install \
  --values ./deploy/helm/services/values.yaml \
  --set global.clusterId="${clusterId}" \
  --set global.namespace="${namespace}" \
  --namespace "${namespace}" \
  "svc-${podNameAM}" "deploy/helm/services/charts/access-manager/"
checkForBashError "$?"
echo "-- Done"
echo " "
echo "-> Helm Unit Test for IDM SVC"
helm unittest deploy/helm/services/charts/idm
echo "-> Installing Identity Manager (IDM) Service(s)"
helm upgrade --install \
  --values ./deploy/helm/services/values.yaml \
  --set global.clusterId="${clusterId}" \
  --set global.namespace="${namespace}" \
  --namespace "${namespace}" \
  "svc-${podNameIDM}" "deploy/helm/services/charts/idm/"
checkForBashError "$?"
echo "-- Done"
echo " "
echo "-> Helm Unit Test for IG SVC"
helm unittest deploy/helm/services/charts/ig
echo "-> Installing Identity Gateway (IG) Service(s)"
helm upgrade --install \
  --values ./deploy/helm/services/values.yaml \
  --set global.clusterId="${clusterId}" \
  --set global.namespace="${namespace}" \
  --namespace "${namespace}" \
  "svc-${podNameIG}" "deploy/helm/services/charts/ig/"
checkForBashError "$?"
echo "-- Done"
echo " "