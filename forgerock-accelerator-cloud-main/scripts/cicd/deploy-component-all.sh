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

# This file contains scripts to deploy the ForgeRock components required by the 
# Midships ForgeRock Cloud Accelerator.

function checkForBashError() {
  if [ "${1}" -ne 0 ]; then
      echo "-- ERROR: Something went wrong. See above logs. Returned '${1}'. Exiting ..."
      exit 1;
  fi
}

echo "======================================"
echo ">>  DEPLOYING FORGEROCK COMPONENTS  <<"
echo "======================================"
echo
source ~/.bashrc

echo "-> Setting variables"
clusterID="dc${CLUSTER_ID:-1}"
podManagementPolivy="${POD_MANAGEMENT_POLICY:-OrderedReady}"
secretsMode="${SECRETS_MODE:-volume}"
k8sLocation="${K8S_LOCATION:-gcp}"
envType="${ENV_TYPE:-dev}"; envType="${envType}-$(date)"
imageTag="${IMAGES_TAG_DEST:-latest}"
namespace="${NAMESPACE:-forgerock}"
registry_url="${CI_REGISTRY_URL:-gcr.io/massive-dynamo-235117}"
k8sClusterDomain="${K8S_CLUSTER_DOMAIN:-cluster.local}"
imgPullSecrets="${IMAGE_PULL_SECRETS}"
lbDomainAM="am${clusterID}.midships.io" #NOTE: For Midships demo environment only
local_helm_config=""

if [[ ${CI_REGISTRY_URL} == *"local"* ]]; then
  k8sLocation="${CI_REGISTRY_URL}"
  local_helm_config="--values ./deploy/helm/apps/environment-config/values-local-dev-overrides.yaml"
  DEPLOY_AM="true"
  DEPLOY_APS="true"
  DEPLOY_TS="true"
  DEPLOY_US="true"
  DEPLOY_IDM="true"
fi

deployAM="${DEPLOY_AM:-false}"
deployAPS="${DEPLOY_APS:-false}"
deployRS_all="${DEPLOY_RS_ALL:-false}"
deployRS_APS="${DEPLOY_RS_APS:-false}"
deployRS_TS="${DEPLOY_RS_TS:-false}"
deployRS_US="${DEPLOY_RS_US:-false}"
deployUS="${DEPLOY_US:-false}"
deployTS="${DEPLOY_TS:-false}"
deployIDM="${DEPLOY_IDM:-false}"
deployIG="${DEPLOY_IG:-false}"

podNameAM="${PODNAME_AM:-forgerock-access-manager}"
[ -n "${PODNAME_AM_GREEN}" ] && podNameAM="${PODNAME_AM_GREEN}"
podNameAPS="${PODNAME_APS:-forgerock-app-policy-store}"
podNameRS="${PODNAME_RS:-forgerock-repl-server}"
podNameUS="${PODNAME_US:-forgerock-user-store}"
podNameTS="${PODNAME_TS:-forgerock-token-store}"
podNameIDM="${PODNAME_IDM:-forgerock-idm}"
podNameIG="${PODNAME_IG:-forgerock-ig}"

replicasAM="${REPLICAS_AM:-1}"
replicasAPS="${REPLICAS_APS:-1}"
replicasRS="${REPLICAS_RS:-1}"
replicasUS="${REPLICAS_US:-1}"
replicasTS="${REPLICAS_TS:-1}"
replicasIDM="${REPLICAS_IDM:-1}"
replicasIG="${REPLICAS_IG:-1}"
replicasAPS="${REPLICAS_APS:-1}"

vaultAddr="${VAULT_ADDR:-https://midships-vault.vault.6ab12ea5-c7af-456f-81b5-e0aaa5c9df5e.aws.hashicorp.cloud:8200}"
secretsmanagerToken="${SECRETS_MANAGER_TOKEN:-s.lvsd4kRuQmUfwY3m4glZ19km}"
secretsmanagerPathRS="${SECRETS_MANAGER_PATH_RS:-forgerock/data/sit/repl-server}"
secretsmanagerPathUS="${SECRETS_MANAGER_PATH_US:-forgerock/data/sit/user-store}"
secretsmanagerPathTS="${SECRETS_MANAGER_PATH_TS:-forgerock/data/sit/token-store}"
secretsmanagerPathAPS="${SECRETS_MANAGER_PATH_APS:-forgerock/data/sit/app-policy-store}"
secretsmanagerPathAM="${SECRETS_MANAGER_PATH_AM:-forgerock/data/sit/access-manager}"
secretsmanagerPathIDM="${SECRETS_MANAGER_PATH_IDM:-forgerock/data/sit/idm}"
secretsmanagerPathIG="${SECRETS_MANAGER_PATH_APS:-forgerock/data/sit/ig}"

imgPathAM=${CONTAINER_IMAGE_CHILD_AM:-"${registry_url}/forgerock-access-manager"}
imgPathAPS=${CONTAINER_IMAGE_CHILD_APS:-"${registry_url}/forgerock-app-policy-store"}
imgPathRS=${CONTAINER_IMAGE_CHILD_RS:-"${registry_url}/forgerock-repl-server"}
imgPathUS=${CONTAINER_IMAGE_CHILD_US:-"${registry_url}/forgerock-user-store"}
imgPathTS=${CONTAINER_IMAGE_CHILD_TS:-"${registry_url}/forgerock-token-store"}
imgPathIDM=${CONTAINER_IMAGE_CHILD_IDM:-"${registry_url}/forgerock-idm"}
imgPathIG=${CONTAINER_IMAGE_CHILD_IG:-"${registry_url}/forgerock-ig"}
echo "-- Done"
echo " "

if [ "${k8sLocation}" == "gcp" ]; then
  if [ "${clusterID}" == "dc1" ]; then
    echo "-- Setting Local Cluster Service IPs"
    svc_ip_rs0_us="34.138.158.174"
    svc_ip_rs1_us="35.227.82.242"
    svc_ip_rs2_us=
    svc_ip_rs0_ts="35.237.189.160"
    svc_ip_rs1_ts="34.23.177.69"
    svc_ip_rs2_ts=
    svc_ip_rs0_aps="34.138.94.34"
    svc_ip_rs1_aps="34.22.155.217"
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
    hostAlias_ip_rs1_aps="34.22.155.217"
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
    clusterId2="dc2"
  elif [ "${clusterID}" == "dc2" ]; then
    echo "-- Setting Local Cluster Service IPs"
    svc_ip_rs0_us="35.240.94.204"
    svc_ip_rs1_us="35.195.187.191"
    svc_ip_rs2_us=
    svc_ip_rs0_ts="35.189.244.206"
    svc_ip_rs1_ts="34.140.49.85"
    svc_ip_rs2_ts=
    svc_ip_rs0_aps="146.148.11.141"
    svc_ip_rs1_aps="34.22.155.217"
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
    hostAlias_ip_rs1_aps="34.22.155.217"
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
    clusterId2="dc1"
  fi
fi

podNameAM="${podNameAM}-${clusterID}"
podNameAPS="${podNameAPS}-${clusterID}"
podNameRS="${podNameRS}-${clusterID}"
podNameRS_APS="${podNameRS}-aps-${clusterID}"
podNameRS_US="${podNameRS}-us-${clusterID}"
podNameRS_TS="${podNameRS}-ts-${clusterID}"
podNameUS="${podNameUS}-${clusterID}"
podNameTS="${podNameTS}-${clusterID}"
podNameIDM="${podNameIDM}-${clusterID}"
podNameIG="${podNameIG}-${clusterID}"
echo "-- Done"
echo " "

echo "-> Dispaly variables"
echo "clusterID is ${clusterID}"
echo "clusterId2 is ${clusterId2}"
echo "podManagementPolivy is ${podManagementPolivy}"
echo "secretsMode is ${secretsMode}"
echo "k8sLocation is ${k8sLocation}"
echo "envType is ${envType}"
echo "imageTag is ${imageTag}"
echo "namespace is ${namespace}"
echo "lbDomainAM is ${lbDomainAM}"
echo "registry_url is ${registry_url}"
echo "k8sClusterDomain is ${k8sClusterDomain}"
echo
echo "deployAM is ${deployAM} | ${DEPLOY_AM}"
echo "deployAPS is ${deployAPS} | ${DEPLOY_APS}"
echo "deployRS_all is ${deployRS_all} | ${DEPLOY_RS_ALL}"
echo "deployRS_APS is ${deployRS_APS} | ${DEPLOY_RS_APS}"
echo "deployRS_TS is ${deployRS_TS} | ${DEPLOY_RS_TS}"
echo "deployRS_US is ${deployRS_US} | ${DEPLOY_RS_US}"
echo "deployTS is ${deployTS} | ${DEPLOY_TS}"
echo "deployUS is ${deployUS} | ${DEPLOY_US}"
echo "deployIDM is ${deployIDM} | ${DEPLOY_IDM}"
echo "deployIG is ${deployIG} | ${DEPLOY_IG}"
echo "local_helm_config is ${local_helm_config}"
echo
if [ "${deployAM}" == "true" ]; then
  echo "podNameAM is ${podNameAM}"
  echo "replicasAM is ${replicasAM}"
fi
if [ "${deployAPS}" == "true" ]; then
  echo "podNameAPS is ${podNameAPS}"
  echo "replicasAPS is ${replicasAPS}"
fi

echo "podNameRS_US is ${podNameRS_US}"
echo "podNameRS_TS is ${podNameRS_TS}"
echo "podNameUS is ${podNameUS}"
echo "podNameTS is ${podNameTS}"
echo "podNameIDM is ${podNameIDM}"
echo "podNameIG is ${podNameIG}"
echo

echo "replicasRS is ${replicasRS}"
echo "replicasUS is ${replicasUS}"
echo "replicasTS is ${replicasTS}"
echo "replicasIDM is ${replicasIDM}"
echo "replicasIG is ${replicasIG}"
echo

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
echo
echo "2nd Cluster Replication IPs"
echo "  > hostAlias_ip_rs0_us: ${hostAlias_ip_rs0_us}"
echo "  > hostAlias_ip_rs1_us: ${hostAlias_ip_rs1_us}"
echo "  > hostAlias_ip_rs2_us: ${hostAlias_ip_rs2_us}"
echo "  > hostAlias_ip_rs0_ts: ${hostAlias_ip_rs0_ts}"
echo "  > hostAlias_ip_rs1_ts: ${hostAlias_ip_rs1_ts}"
echo "  > hostAlias_ip_rs2_ts: ${hostAlias_ip_rs2_ts}"
echo "  > hostAlias_ip_rs0_aps: ${hostAlias_ip_rs0_aps}"
echo "  > hostAlias_ip_rs1_aps: ${hostAlias_ip_rs1_aps}"
echo "  > hostAlias_ip_rs2_aps: ${hostAlias_ip_rs2_aps}"
echo "  > hostAlias_ip_us0: ${hostAlias_ip_us0}"
echo "  > hostAlias_ip_us1: ${hostAlias_ip_us1}"
echo "  > hostAlias_ip_us2: ${hostAlias_ip_us2}"
echo "  > hostAlias_ip_ts0: ${hostAlias_ip_ts0}"
echo "  > hostAlias_ip_ts1: ${hostAlias_ip_ts1}"
echo "  > hostAlias_ip_ts2: ${hostAlias_ip_ts2}"
echo "  > hostAlias_ip_aps0: ${hostAlias_ip_aps0}"
echo "  > hostAlias_ip_aps1: ${hostAlias_ip_aps1}"
echo "  > hostAlias_ip_aps2: ${hostAlias_ip_aps2}"
echo "-- Done"
echo " "

if [ "${deployRS_all,,}" == "true"  ] || [ "${deployRS_APS,,}" == "true" ] || [ "${deployRS_TS,,}" == "true"  ] || [ "${deployRS_US,,}" == "true"  ] ; then
  echo "-> Helm Unit Test RS Apps "
  helm unittest deploy/helm/apps/charts/repl-server
fi
if [ "${deployRS_all,,}" == "true" ]; then
  echo "-> Installing Replication Server (for User, Token and Application Policy Store)"
  helm upgrade --install \
    --values ./deploy/helm/apps/values.yaml \
    --set global.podManagementPolivy="${podManagementPolivy}" \
    --set global.clusterId="${clusterID}" \
    --set global.registryURL="${registry_url}" \
    --set global.imageTag="${imageTag}" \
    --set global.envType="${envType}" \
    --set global.secretsMode="${secretsMode}" \
    --set global.k8sLocation="${k8sLocation}" \
    --set global.imgPullSecrets="${imgPullSecrets}" \
    --set global.namespace="${namespace}" \
    --set replserver.aps.replicas="${replicasRS}" \
    --set replserver.ts.replicas="${replicasRS}" \
    --set replserver.us.replicas="${replicasRS}" \
    --set replserver.ts.hostAliases_ip1="${hostAlias_ip_rs0_ts}" \
    --set replserver.ts.hostAliases_ip2="${hostAlias_ip_rs1_ts}" \
    --set replserver.ts.hostAliases_ip3="${hostAlias_ip_rs2_ts}" \
    --set replserver.us.hostAliases_ip1="${hostAlias_ip_rs0_us}" \
    --set replserver.us.hostAliases_ip2="${hostAlias_ip_rs1_us}" \
    --set replserver.us.hostAliases_ip3="${hostAlias_ip_rs2_us}" \
    --set replserver.aps.hostAliases_ip1="${hostAlias_ip_rs0_aps}" \
    --set replserver.aps.hostAliases_ip2="${hostAlias_ip_rs1_aps}" \
    --set replserver.aps.hostAliases_ip3="${hostAlias_ip_rs2_aps}" \
    --set userstore.hostAliases_ip1="${hostAlias_ip_us0}" \
    --set userstore.hostAliases_ip2="${hostAlias_ip_us1}" \
    --set userstore.hostAliases_ip3="${hostAlias_ip_us2}" \
    --set tokenstore.hostAliases_ip1="${hostAlias_ip_ts0}" \
    --set tokenstore.hostAliases_ip2="${hostAlias_ip_ts1}" \
    --set tokenstore.hostAliases_ip3="${hostAlias_ip_ts2}" \
    --set aps.hostAliases_ip1="${hostAlias_ip_aps0}" \
    --set aps.hostAliases_ip2="${hostAlias_ip_aps1}" \
    --set aps.hostAliases_ip3="${hostAlias_ip_aps2}" \
    --namespace "${namespace}" \
    "${podNameRS}" "deploy/helm/apps/charts/repl-server/"
    checkForBashError "$?"
  echo "-- Done"
  echo " "
fi

if [ "${deployRS_APS,,}" == "true" ]; then
  echo "-> Installing Replication Server (for Application Policy Store)"
  helm template \
    --values ./deploy/helm/apps/values.yaml ${local_helm_config} \
    --values ./deploy/helm/apps/charts/repl-server/values.yaml \
    --set global.podManagementPolivy="${podManagementPolivy}" \
    --set global.clusterId="${clusterID}" \
    --set global.registryURL="${registry_url}" \
    --set global.imageTag="${imageTag}" \
    --set global.envType="${envType}" \
    --set global.secretsMode="${secretsMode}" \
    --set global.k8sLocation="${k8sLocation}" \
    --set global.imgPullSecrets="${imgPullSecrets}" \
    --set global.namespace="${namespace}" \
    --set replserver.aps.replicas="${replicasRS}" \
    --set replserver.aps.hostAliases_ip1="${hostAlias_ip_rs0_aps}" \
    --set replserver.aps.hostAliases_ip2="${hostAlias_ip_rs1_aps}" \
    --set replserver.aps.hostAliases_ip3="${hostAlias_ip_rs2_aps}" \
    --set aps.hostAliases_ip1="${hostAlias_ip_aps0}" \
    --set aps.hostAliases_ip2="${hostAlias_ip_aps1}" \
    --set aps.hostAliases_ip3="${hostAlias_ip_aps2}" \
    --namespace "${namespace}" \
    --show-only "templates/deploy-rs-aps.yaml" \
    "${podNameRS_APS}" "deploy/helm/apps/charts/repl-server/" | kubectl apply -f -
    checkForBashError "$?"
  echo "-- Done"
  echo " "
fi

if [ "${deployRS_TS,,}" == "true" ]; then
  echo "-> Installing Replication Server (for Token Store)"
  helm template \
    --values ./deploy/helm/apps/values.yaml ${local_helm_config} \
    --values ./deploy/helm/apps/charts/repl-server/values.yaml \
    --set global.podManagementPolivy="${podManagementPolivy}" \
    --set global.clusterId="${clusterID}" \
    --set global.registryURL="${registry_url}" \
    --set global.imageTag="${imageTag}" \
    --set global.envType="${envType}" \
    --set global.secretsMode="${secretsMode}" \
    --set global.k8sLocation="${k8sLocation}" \
    --set global.imgPullSecrets="${imgPullSecrets}" \
    --set global.namespace="${namespace}" \
    --set replserver.ts.replicas="${replicasRS}" \
    --set replserver.ts.hostAliases_ip1="${hostAlias_ip_rs0_ts}" \
    --set replserver.ts.hostAliases_ip2="${hostAlias_ip_rs1_ts}" \
    --set replserver.ts.hostAliases_ip3="${hostAlias_ip_rs2_ts}" \
    --set tokenstore.hostAliases_ip1="${hostAlias_ip_ts0}" \
    --set tokenstore.hostAliases_ip2="${hostAlias_ip_ts1}" \
    --set tokenstore.hostAliases_ip3="${hostAlias_ip_ts2}" \
    --namespace "${namespace}" \
    --show-only "templates/deploy-rs-ts.yaml" \
    "${podNameRS_TS}" "deploy/helm/apps/charts/repl-server/" | kubectl apply -f -
    checkForBashError "$?"
  echo "-- Done"
  echo " "
fi

if [ "${deployRS_US,,}" == "true" ]; then
  echo "-> Installing Replication Server (for User Store)"
  helm template \
    --values ./deploy/helm/apps/values.yaml ${local_helm_config} \
    --values ./deploy/helm/apps/charts/repl-server/values.yaml \
    --set global.podManagementPolivy="${podManagementPolivy}" \
    --set global.clusterId="${clusterID}" \
    --set global.registryURL="${registry_url}" \
    --set global.imageTag="${imageTag}" \
    --set global.envType="${envType}" \
    --set global.secretsMode="${secretsMode}" \
    --set global.k8sLocation="${k8sLocation}" \
    --set global.imgPullSecrets="${imgPullSecrets}" \
    --set global.namespace="${namespace}" \
    --set replserver.aps.replicas="${replicasRS}" \
    --set replserver.ts.replicas="${replicasRS}" \
    --set replserver.us.replicas="${replicasRS}" \
    --set replserver.us.hostAliases_ip1="${hostAlias_ip_rs0_us}" \
    --set replserver.us.hostAliases_ip2="${hostAlias_ip_rs1_us}" \
    --set replserver.us.hostAliases_ip3="${hostAlias_ip_rs2_us}" \
    --set userstore.hostAliases_ip1="${hostAlias_ip_us0}" \
    --set userstore.hostAliases_ip2="${hostAlias_ip_us1}" \
    --set userstore.hostAliases_ip3="${hostAlias_ip_us2}" \
    --namespace "${namespace}" \
    --show-only "templates/deploy-rs-us.yaml" \
    "${podNameRS_US}" "deploy/helm/apps/charts/repl-server/" | kubectl apply -f -
    checkForBashError "$?"
  echo "-- Done"
  echo " "
fi

if [ "${deployRS_all,,}" == "true" ] || [ "${deployRS_APS,,}" == "true" ] || [ "${deployRS_TS,,}" == "true" ] || [ "${deployRS_US,,}" == "true" ]; then
  waitTimeTotSecs=120
  waitTimeTCurSecs=0
  echo "-- INFO: Waiting ${waitTimeTotSecs} seconds for Replication Server(s) deployment"
  while [ "${waitTimeTCurSecs}" -lt "${waitTimeTotSecs}" ]; do
    sleep 5;
    waitTimeTCurSecs=$(( $waitTimeTCurSecs + 5 ));
    waitTimeTCurSecsStr=$(printf "%02d\n" $((waitTimeTCurSecs)))
    echo "[ ${waitTimeTCurSecsStr}/${waitTimeTotSecs} ]";
  done
  echo " "
fi

if [ "${deployUS,,}" == "true" ]; then
  echo "-> Helm Unit Test US Apps "
  helm unittest deploy/helm/apps/charts/user-store
  echo "-> Installing User Store"
  #helm upgrade --install --wait --timeout 2m30s \
  helm upgrade --install \
    --values ./deploy/helm/apps/values.yaml ${local_helm_config} \
    --set global.podManagementPolivy="${podManagementPolivy}" \
    --set global.clusterId="${clusterID}" \
    --set global.registryURL="${registry_url}" \
    --set global.imageTag="${imageTag}" \
    --set global.envType="${envType}" \
    --set global.secretsMode="${secretsMode}" \
    --set global.k8sLocation="${k8sLocation}" \
    --set global.imgPullSecrets="${imgPullSecrets}" \
    --set global.namespace="${namespace}" \
    --set userstore.replicas="${replicasUS}" \
    --set replserver.hostAliases_ip1="${hostAlias_ip_rs0_us}" \
    --set replserver.hostAliases_ip2="${hostAlias_ip_rs1_us}" \
    --set replserver.hostAliases_ip3="${hostAlias_ip_rs2_us}" \
    --set userstore.hostAliases_ip1="${hostAlias_ip_us0}" \
    --set userstore.hostAliases_ip2="${hostAlias_ip_us1}" \
    --set userstore.hostAliases_ip3="${hostAlias_ip_us2}" \
    --set userstore.namespace="${namespace}" \
    --namespace "${namespace}" \
    "${podNameUS}" "deploy/helm/apps/charts/user-store/"
    checkForBashError "$?"
  echo "-- Done"
  echo " "
fi

if [ "${deployAPS,,}" == "true" ]; then
  echo "-> Helm Unit Test APS Apps "
  helm unittest deploy/helm/apps/charts/app-policy-store
  echo "-> Installing Application and Policy Store"
  helm upgrade --install \
    --values ./deploy/helm/apps/values.yaml ${local_helm_config} \
    --set global.podManagementPolivy="${podManagementPolivy}" \
    --set global.clusterId="${clusterID}" \
    --set global.registryURL="${registry_url}" \
    --set global.imageTag="${imageTag}" \
    --set global.envType="${envType}" \
    --set global.secretsMode="${secretsMode}" \
    --set global.k8sLocation="${k8sLocation}" \
    --set global.imgPullSecrets="${imgPullSecrets}" \
    --set global.namespace="${namespace}" \
    --set aps.replicas="${replicasAPS}" \
    --set replserver.hostAliases_ip1="${hostAlias_ip_rs0_aps}" \
    --set replserver.hostAliases_ip2="${hostAlias_ip_rs1_aps}" \
    --set replserver.hostAliases_ip3="${hostAlias_ip_rs2_aps}" \
    --set aps.hostAliases_ip1="${hostAlias_ip_aps0}" \
    --set aps.hostAliases_ip2="${hostAlias_ip_aps1}" \
    --set aps.hostAliases_ip3="${hostAlias_ip_aps2}" \
    --set aps.namespace="${namespace}" \
    --namespace "${namespace}" \
    "${podNameAPS}" "deploy/helm/apps/charts/app-policy-store/"
    checkForBashError "$?"
  echo "-- Done"
  echo " "
fi

if [ "${deployTS,,}" == "true" ]; then
  echo "-> Helm Unit Test TS Apps "
  helm unittest deploy/helm/apps/charts/token-store
  echo "-> Installing Token Store"
  helm upgrade --install \
    --values ./deploy/helm/apps/values.yaml ${local_helm_config} \
    --set global.podManagementPolivy="${podManagementPolivy}" \
    --set global.clusterId="${clusterID}" \
    --set global.registryURL="${registry_url}" \
    --set global.imageTag="${imageTag}" \
    --set global.envType="${envType}" \
    --set global.secretsMode="${secretsMode}" \
    --set global.k8sLocation="${k8sLocation}" \
    --set global.imgPullSecrets="${imgPullSecrets}" \
    --set global.namespace="${namespace}" \
    --set tokenstore.replicas="${replicasTS}" \
    --set replserver.hostAliases_ip1="${hostAlias_ip_rs0_ts}" \
    --set replserver.hostAliases_ip2="${hostAlias_ip_rs1_ts}" \
    --set replserver.hostAliases_ip3="${hostAlias_ip_rs2_ts}" \
    --set tokenstore.hostAliases_ip1="${hostAlias_ip_ts0}" \
    --set tokenstore.hostAliases_ip2="${hostAlias_ip_ts1}" \
    --set tokenstore.hostAliases_ip3="${hostAlias_ip_ts2}" \
    --set tokenstore.namespace="${namespace}" \
    --namespace "${namespace}" \
    "${podNameTS}" "deploy/helm/apps/charts/token-store/"
    checkForBashError "$?"
  echo "-- Done"
  echo " "
fi

if [ "${deployAPS,,}" == "true" ] || [ "${deployTS,,}" == "true" ] || [ "${deployUS,,}" == "true" ]; then
  waitTimeTotSecs=120
  waitTimeTCurSecs=0
  echo "-- INFO: Waiting ${waitTimeTotSecs} seconds for Directory Server(s) deployment"
  while [ "${waitTimeTCurSecs}" -lt "${waitTimeTotSecs}" ]; do
    sleep 5;
    waitTimeTCurSecs=$(( $waitTimeTCurSecs + 5 ));
    waitTimeTCurSecsStr=$(printf "%02d\n" $((waitTimeTCurSecs)))
    echo "[ ${waitTimeTCurSecsStr}/${waitTimeTotSecs} ]";
  done
  echo " "
fi

if [ "${deployAM,,}" == "true" ]; then
  echo "-> Helm Unit Test US Apps "
#  helm unittest deploy/helm/apps/charts/access-manager
  echo "-> Installing Access Manager"
  helm upgrade --install \
    --values ./deploy/helm/apps/values.yaml ${local_helm_config} \
    --set global.podManagementPolivy="${podManagementPolivy}" \
    --set global.clusterId="${clusterID}" \
    --set global.registryURL="${registry_url}" \
    --set global.imageTag="${imageTag}" \
    --set global.envType="${envType}" \
    --set global.secretsMode="${secretsMode}" \
    --set global.k8sLocation="${k8sLocation}" \
    --set global.imgPullSecrets="${imgPullSecrets}" \
    --set global.namespace="${namespace}" \
    --set am.replicas="${replicasAM}" \
    --set am.namespace="${namespace}" \
    --set am.lbDomain="${lbDomainAM}" \
    --namespace "${namespace}" \
    "${podNameAM}" "deploy/helm/apps/charts/access-manager/"
    checkForBashError "$?"
  echo "-- Done"
  echo " "
fi

# Moved to end to ensure last User Store is up and running or close before execution
if ([ "${deployIDM,,}" == "true" ]); then
  echo "-> Installing Identity Manager (IDM)"
  echo "-> Helm Unit Test US Apps "
  helm unittest deploy/helm/apps/charts/identity-manager
  helm upgrade --install \
    --values ./deploy/helm/apps/values.yaml ${local_helm_config} \
    --set global.clusterId="${clusterID}" \
    --set global.registryURL="${registry_url}" \
    --set global.imageTag="${imageTag}" \
    --set global.envType="${envType}" \
    --set global.secretsMode="${secretsMode}" \
    --set global.k8sLocation="${k8sLocation}" \
    --set global.imgPullSecrets="${imgPullSecrets}" \
    --set global.namespace="${namespace}" \
    --set idm.replicas="${replicasIDM}" \
    --set idm.namespace="${namespace}" \
    --namespace "${namespace}" \
    "${podNameIDM}" "deploy/helm/apps/charts/identity-manager/"
    checkForBashError "$?"
  echo "-- Done"
  echo " "
fi

if [ "${deployIG,,}" == "true" ]; then
  echo "-> Helm Unit Test US Apps "
  helm unittest deploy/helm/apps/charts/identity-gateway
  echo "-> Installing Identity Gateway (IG)"
  helm upgrade --install \
    --values ./deploy/helm/apps/values.yaml ${local_helm_config} \
    --set global.podManagementPolivy="${podManagementPolivy}" \
    --set global.clusterId="${clusterID}" \
    --set global.registryURL="${registry_url}" \
    --set global.imageTag="${imageTag}" \
    --set global.envType="${envType}" \
    --set global.secretsMode="${secretsMode}" \
    --set global.k8sLocation="${k8sLocation}" \
    --set global.imgPullSecrets="${imgPullSecrets}" \
    --set global.namespace="${namespace}" \
    --set ig.replicas="${replicasIG}" \
    --set ig.namespace="${namespace}" \
    --namespace "${namespace}" \
    "${podNameIG}" "deploy/helm/apps/charts/identity-gateway/"
    checkForBashError "$?"
  echo "-- Done"
  echo " "
fi