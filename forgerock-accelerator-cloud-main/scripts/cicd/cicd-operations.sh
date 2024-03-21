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

function setupRequiredTools(){
  echo "================================="
  echo ">>  SETTING UP REQUIRED TOOLS  <<"
  echo "================================="
  echo
  # install required tools
  # apk update && apk add curl bash wget tar python3 py-pip
  echo "-> Installing kubectl"
  curl -l https://storage.googleapis.com/kubernetes-release/release/v1.26.1/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
  chmod u+x /usr/local/bin/kubectl
  kubectl version
  echo "-- Done"
  echo " "
  echo "-> Setttig up kube config"
  echo "-- Creatig '${HOME}/.kube/'"
  mkdir -p "${HOME}/.kube/"
  echo "-- Listing contents"
  ls -ltr "${HOME}/.kube/"
  echo "-- Adding provided FR_KUBE_CONFG"
  if [ "${CLUSTER_ID}" == "1" ]; then
    echo "-- Using FR_KUBE_CONFIG for kubeconfig"
    echo ${FR_KUBE_CONFIG} | base64 -d > "${HOME}/.kube/config"
  else
    echo "-- Using FR_KUBE_CONFIG2 for kubeconfig"
    echo ${FR_KUBE_CONFIG2} | base64 -d > "${HOME}/.kube/config"
  fi
  chmod 600 "${HOME}/.kube/config"
  echo "-- Listing updated contents"
  # ls -ltr "${HOME}/.kube/"
  # echo "-- Viewing contents"
  # cat "${HOME}/.kube/config"
  echo "-- Done"
  echo " "

  echo "-> Installing Helm"
  export VERIFY_CHECKSUM=false
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  helm version
  cd ${HOME}
  echo "-- Done"
  echo " "
  echo "-> Installing Helm Unit Test"
  helm plugin install https://github.com/helm-unittest/helm-unittest.git
  echo "-- the K8S_LOCATION is set to ${K8S_LOCATION}"
  echo " "
  if [ "${K8S_LOCATION}" == "gcp" ]; then
    # echo "-> download and install google cloud sdk"
    # wget https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz    
    # tar zxf google-cloud-sdk.tar.gz
    # ./google-cloud-sdk/install.sh --usage-reporting=false --path-update=true --quiet
    # google-cloud-sdk/bin/gcloud --quiet components update
    #path_gcloud_install_dir="$(google-cloud-sdk/bin/gcloud info --format="value(installation.sdk_root)")"
    path_gcloud_install_dir="$(gcloud info --format="value(installation.sdk_root)")"
    echo "gcloud installed at ${path_gcloud_install_dir}"
    echo "${GCP_SERVICE_KEY}" | base64 -d  >> ${home}/gcloud-service-key.json
    #google-cloud-sdk/bin/gcloud auth activate-service-account --key-file ${home}/gcloud-service-key.json
    gcloud auth activate-service-account --key-file ${home}/gcloud-service-key.json
    # echo "export PATH=${path_gcloud_install_dir}/bin:${PATH}" >> ~/.bashrc
    # source ~/.bashrc
    echo "-- Done"
    echo " "
    #gcloud container clusters get-credentials "${GCP_K8S_CLUSTER_NAME}" --region "${GCP_K8S_ZONE}" --project "${GCP_PROJECTID}"
    # ls -ltr "${HOME}/.kube/"
    # echo "-- Viewing contents"
    # cat "${HOME}/.kube/config"
    echo "-- Done"
    echo " "
    
    echo "-> Installing gke-gcloud-auth-plugin"
    gcloud components install gke-gcloud-auth-plugin
    echo "-- Version is:"
    gke-gcloud-auth-plugin --version  
    gcloud components update
    echo "-- Done"
    echo " "
  elif [ "${K8S_LOCATION}" == "aws" ]; then
    echo "-> download and install aws cli"
    pip install awscli
    aws --version
    aws configure set aws_access_key_id ${aws_access_key_id}
    aws configure set aws_secret_access_key ${aws_secret_access_key}
    echo "-- done"
    echo " "
  elif [ "${K8S_LOCATION}" == "azure" ]; then
    echo "-> download and install azure cli"
    apt-get update -y
    apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg
    curl -sl https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
    az_repo=$(lsb_release -cs)
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $az_repo main" |
    tee /etc/apt/sources.list.d/azure-cli.list
    apt-get update -y
    apt-get install -y azure-cli
    az aks install-cli
    az login --use-device-code
    az account set --subscription ${azure_subscription_id}
    az aks get-credentials --resource-group ${azure_resource_group_name} --name ${azure_aks_name} --admin
    echo "-- done"
    echo " "
  else
    echo "-- ERROR: K8S_LOCATION is not set to 'azure', 'gcp', or 'azure' "
    echo "-- Exiting ..."
    exit 1
  fi
}

case "${1}" in
  "setup-tools")
    setupRequiredTools
    ;;
  *)
    echo "-- ERROR: Invalid input '${1}' provided."
    ;;
esac