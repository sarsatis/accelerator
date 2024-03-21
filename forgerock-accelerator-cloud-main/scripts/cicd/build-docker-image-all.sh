# Shebang in this file causes error in Gitlab CI : #!/usr/bin/env bash
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

# This file contains scripts to" "build the Docker images required by the 
# Midships ForgeRock Cloud Accelerator.

function logIntoContainerRegistry() {
  echo ">> Logging into Container Registry <<"
  mkdir -p "${HOME}/.docker"
  echo "Length of GCP_SERVICE_KEY is ${#GCP_SERVICE_KEY}"
  if [ "${#GCP_SERVICE_KEY}" -gt 0 ] && [ -n "${#GCP_SERVICE_KEY}" ]; then
    echo "${GCP_SERVICE_KEY}" | base64 -d >> "$HOME/.docker/config.json"
    docker login -u _json_key --password-stdin https://gcr.io < $HOME/.docker/config.json
    docker info
  else
    echo "-- ERROR: GCP_SERVICE_KEY is empty. Please check Environment Variables."
    errorFound="true"
  fi
  echo "-- Done"
  echo " "
  if [ "${errorFound}" == "true" ]; then
    echo "-- ERROR: Something went wrong. See above logs. Exiting ..."
    exit 1
  fi
}

function checkForBashError() {
  if [ "${1}" -ne 0 ]; then
      echo "-- ERROR: Something went wrong. See above logs. Returned '${1}'. Exiting ..."
      exit 1;
  fi
}

function imageBuild(){
  local artifactory_source="${1:-none}"
  local artifactory_baseUrl="${2:-none}"
  local containerRegistry_imageSrcPath="${3:-none}"
  local containerRegistry_imageSrcTag="${4:-none}"
  local artifactory_uname="${5:-none}"
  local artifactory_pword="${6:-none}"
  local containerRegistry_imageDestPath="${7:-none}"
  local containerRegistry_imageDestTag="${8:-none}"
  local pathDir_dockerfile="${9%/}"
  local additionalAttr="${10}"
  local mac_build_args=""
  if [ "${CI_REGISTRY_URL}" == "local-mac" ] && [ "${pathDir_dockerfile}" == "build/base-images/java-base" ]; then
    mac_build_args="--build-arg jdk_path='jdk-16' --build-arg filename_jdk='openjdk-16_linux-aarch64_bin.tar.gz'"
  fi
  if [ "${CI_REGISTRY_URL}" == "local-mac" ] && [ "${pathDir_dockerfile}" == "build/base-images/fact-base" ]; then
    mac_build_args="--build-arg nodeVersion='v20.11.0' --build-arg distro='linux-arm64'"
  fi
  local buildCommand=$( echo docker build ${mac_build_args} ${IMAGE_BUILD_CACHE_ARG} ${additionalAttr} \
    --build-arg artifactory_source="'${artifactory_source}'" --build-arg artifactory_baseUrl="'${artifactory_baseUrl}'" \
    --build-arg image_src="'${containerRegistry_imageSrcPath}'" --build-arg image_tag="'${containerRegistry_imageSrcTag}'" \
    --build-arg artifactory_uname="'${artifactory_uname}'" --build-arg artifactory_pword="'${artifactory_pword}'" \
    -t "'${containerRegistry_imageDestPath}:${containerRegistry_imageDestTag}'" \
    "'${pathDir_dockerfile}/.'" )

  [ ! -d "./${pathDir_dockerfile}" ] && echo "-- ERROR: Dockerfile folder './${pathDir_dockerfile}' NOT found." && exit 1

  echo "-- INFO: Executing BUILD command ..."
  echo "-- FROM: ${containerRegistry_imageSrcPath}:${containerRegistry_imageSrcTag}"
#  echo "${buildCommand}"
  eval "${buildCommand}"
  checkForBashError "$?"
}

function imagePush() {
  if [ "${IMAGE_PUSH_ENABLED}" == "true" ]; then
    local containerRegistry_imagePath="${1}"
    local containerRegistry_imageTag="${2}"
    pushCommand=$( echo docker push "'${containerRegistry_imagePath}:${containerRegistry_imageTag}'" )
    echo "-- INFO: Executing PUSH command:"
    echo "${pushCommand}"
    eval "${pushCommand}"
    checkForBashError "$?"
  else
    echo "-- INFO: Image PUSH disabled - skipping"
  fi
}

function imageTest() {
  if [ "${IMAGE_TEST_ENABLED}" == "true" ]; then
    local imagePath="${1}"
    chmod 770 "${imagePath}/test.sh"
    # For now - don't fail if the file doesn't exist
    if test -f "${imagePath}/test.sh"; then
      echo 'File exists.'
      testCommand=$( echo "'${imagePath}/test.sh'" )
      echo "-- INFO: Executing TEST command:"
      echo "${testCommand}"
      eval "${testCommand}"
      checkForBashError "$?"
    else
      echo "-- INFO: Image TEST script not present - skipping"
    fi
  else
    echo "-- INFO: Image TEST disabled - skipping"
  fi
}

function buildImages() {
  local sleepTimerSecs=5
  CI_COMMIT_REF_NAME="${CI_COMMIT_REF_NAME:-NA}"
  echo "============================"
  echo ">> BUILDING DOCKER IMAGES <<"
  echo "============================"
  echo "   Code Branch: ${CI_COMMIT_REF_NAME}"
  echo " "

  echo "-> Setting variables"
  errorFound="false"
  BINARY_LOCATION="${BINARY_LOCATION:-sftp}" # Allowed: sftp, gcp, aws
  STORAGE_BUCKET_PATH_BIN="${STORAGE_BUCKET_PATH_BIN}" # E.g. sftp://ruhles.freeddns.org:22100
  CI_REGISTRY_URL="${CI_REGISTRY_URL}" # E.g. gcr.io/massive-dynamo-1234567
  SFTP_UNAME="${SFTP_UNAME}"
  SFTP_PWORD="${SFTP_PWORD}"
  CONTAINER_IMAGE_BASE_JAVA=${CI_REGISTRY_URL}/java-base
  CONTAINER_IMAGE_BASE_TOMCAT=${CI_REGISTRY_URL}/tomcat-base
  CONTAINER_IMAGE_BASE_AM=${CI_REGISTRY_URL}/forgerock-am-base
  CONTAINER_IMAGE_BASE_DS=${CI_REGISTRY_URL}/forgerock-ds-base
  CONTAINER_IMAGE_BASE_IDM=${CI_REGISTRY_URL}/forgerock-idm-base
  CONTAINER_IMAGE_BASE_IG=${CI_REGISTRY_URL}/forgerock-ig-base
  CONTAINER_IMAGE_BASE_FACT=${CI_REGISTRY_URL}/fact-base
  CONTAINER_IMAGE_CHILD_AM=${CI_REGISTRY_URL}/forgerock-access-manager
  CONTAINER_IMAGE_CHILD_APS=${CI_REGISTRY_URL}/forgerock-app-policy-store
  CONTAINER_IMAGE_CHILD_RS=${CI_REGISTRY_URL}/forgerock-repl-server
  CONTAINER_IMAGE_CHILD_US=${CI_REGISTRY_URL}/forgerock-user-store
  CONTAINER_IMAGE_CHILD_TS=${CI_REGISTRY_URL}/forgerock-token-store
  CONTAINER_IMAGE_CHILD_IDM=${CI_REGISTRY_URL}/forgerock-idm
  CONTAINER_IMAGE_CHILD_IG=${CI_REGISTRY_URL}/forgerock-ig
  CONTAINER_IMAGE_CHILD_PS=${CI_REGISTRY_URL}/forgerock-policy-store
  CONTAINER_IMAGE_CHILD_FACT=${CI_REGISTRY_URL}/midships-fact
  IMAGES_TAG_SRC="${IMAGES_TAG_SRC:-7.3}"
  IMAGES_TAG_DEST="${IMAGES_TAG_DEST:-7.3}"
  BUILD_ALL="${BUILD_ALL:-false}" # Set this to 'true' to build all images in sequence
  BUILDBASE_ALL="${BUILDBASE_ALL:-${BUILD_ALL}}" # Set this to 'true' to build all base images in sequence
  BUILDCHILD_ALL="${BUILDCHILD_ALL:-${BUILD_ALL}}" # Set this to 'true' to build all child images in sequence
  BUILDBASE_JAVA="${BUILDBASE_JAVA:-${BUILDBASE_ALL}}"
  BUILDBASE_TOMCAT="${BUILDBASE_TOMCAT:-${BUILDBASE_ALL}}"
  BUILDBASE_AM="${BUILDBASE_AM:-${BUILDBASE_ALL}}"
  BUILDBASE_DS="${BUILDBASE_DS:-${BUILDBASE_ALL}}"
  BUILDBASE_IDM="${BUILDBASE_IDM:-${BUILDBASE_ALL}}"
  BUILDBASE_FACT="${BUILDBASE_FACT:-${BUILDBASE_ALL}}"
  BUILDBASE_IG="${BUILDBASE_IG:-${BUILDBASE_ALL}}"
  BUILDCHILD_RS="${BUILDCHILD_RS:-${BUILDCHILD_ALL}}"
  BUILDCHILD_APS="${BUILDCHILD_APS:-${BUILDCHILD_ALL}}"
  BUILDCHILD_US="${BUILDCHILD_US:-${BUILDCHILD_ALL}}"
  BUILDCHILD_TS="${BUILDCHILD_TS:-${BUILDCHILD_ALL}}"
  BUILDCHILD_AM="${BUILDCHILD_AM:-${BUILDCHILD_ALL}}"
  BUILDCHILD_IDM="${BUILDCHILD_IDM:-${BUILDCHILD_ALL}}"
  BUILDCHILD_FACT="${BUILDCHILD_FACT:-${BUILDCHILD_ALL}}"
  BUILDCHILD_IG="${BUILDCHILD_IG:-${BUILDCHILD_ALL}}"
  IMAGE_PUSH_ENABLED="${IMAGE_PUSH_ENABLED:-true}"
  IMAGE_TEST_ENABLED="${IMAGE_TEST_ENABLED:-true}"
  IMAGE_BUILD_CACHE_ENABLED="${IMAGE_BUILD_CACHE_ENABLED:-"true"}"
  IMAGE_BUILD_CACHE_ARG=""
  echo "-- Done"
  echo " "

  echo "-> Verifying key variables"
  [ -z "${BINARY_LOCATION}" ] && echo "-- ERROR: BINARY_LOCATION is empty. Please set to sftp, aws, gcp." && errorFound="true"
  [ -z "${STORAGE_BUCKET_PATH_BIN}" ] && echo "-- ERROR: STORAGE_BUCKET_PATH_BIN is empty. Please set to your artifactory base URL." && errorFound="true"
  [ -z "${CI_REGISTRY_URL}" ] && echo "-- ERROR: CI_REGISTRY_URL is empty. Please set to your container registry base URL." && errorFound="true"
  if [ "${BINARY_LOCATION}" == "sftp" ]; then
    [ -z "${SFTP_UNAME}" ] && echo "-- ERROR: SFTP_UNAME is empty." && errorFound="true"
    [ -z "${SFTP_PWORD}" ] && echo "-- ERROR: SFTP_PWORD is empty." && errorFound="true"
  fi
  echo "-- Done"
  echo " "

  echo "-> Key Variables"
  echo "   BINARY_LOCATION: '${BINARY_LOCATION}'"
  echo "   STORAGE_BUCKET_PATH_BIN: '${STORAGE_BUCKET_PATH_BIN}'"
  echo "   CI_REGISTRY_URL: '${CI_REGISTRY_URL}'"
  echo "   SFTP_UNAME: '${SFTP_UNAME}'"
  echo "   SFTP_PWORD length: '${#SFTP_PWORD}'"
  echo "   IMAGES_TAG_SRC: '${IMAGES_TAG_SRC}'"
  echo "   IMAGES_TAG_DEST: '${IMAGES_TAG_DEST}'"
  echo "   --"
  echo "   BUILDBASE_JAVA: '${BUILDBASE_JAVA}'"
  echo "   BUILDBASE_TOMCAT: '${BUILDBASE_TOMCAT}'"
  echo "   BUILDBASE_AM: '${BUILDBASE_AM}'"
  echo "   BUILDBASE_DS: '${BUILDBASE_DS}'"
  echo "   BUILDBASE_IDM: '${BUILDBASE_IDM}'"
  echo "   BUILDBASE_FACT: '${BUILDBASE_FACT}'"
  echo "   BUILDBASE_IG: '${BUILDBASE_IG}'"
  echo "   BUILDCHILD_RS: '${BUILDCHILD_RS}'"
  echo "   BUILDCHILD_APS: '${BUILDCHILD_APS}'"
  echo "   BUILDCHILD_US: '${BUILDCHILD_US}'"
  echo "   BUILDCHILD_TS: '${BUILDCHILD_TS}'"
  echo "   BUILDCHILD_AM: '${BUILDCHILD_AM}'"
  echo "   BUILDCHILD_IDM: '${BUILDCHILD_IDM}'"
  echo "   BUILDCHILD_FACT: '${BUILDCHILD_FACT}'"
  echo "   BUILDCHILD_IG: '${BUILDCHILD_IG}'"
  echo "   IMAGE_PUSH_ENABLED: '${IMAGE_PUSH_ENABLED}'"
  echo "   IMAGE_BUILD_CACHE_ENABLED: '${IMAGE_BUILD_CACHE_ENABLED}'"
  echo "-- Done"
  echo " "

  if [ -z "${IMAGE_BUILD_CACHE_ENABLED}" ]; then
    echo "Docker build cache enabled"
    IMAGE_BUILD_CACHE_ARG="--no-cache"
  fi

  # Add code to log into container registry with docker. For instance
  # docker login -u _json_key --password-stdin https://gcr.io < $HOME"docker/config.json

  if [ "${errorFound}" == "false" ]; then
    if [ "${BUILDBASE_JAVA}" == "true" ]; then
      echo "-> Building Java Base -  START"
      IMAGE_CODE_LOCATION="build/base-images/java-base"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "" "" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_BASE_JAVA}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}"
      imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_BASE_JAVA}" "${IMAGES_TAG_DEST}"
      echo "-- Building Java Base - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
    if [ "${BUILDBASE_TOMCAT}" == "true" ]; then
      echo "-> Building Tomcat Base -  START"
      IMAGE_CODE_LOCATION="build/base-images/tomcat-base"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "${CONTAINER_IMAGE_BASE_JAVA}" "${IMAGES_TAG_SRC}" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_BASE_TOMCAT}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}"
        imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_BASE_TOMCAT}" "${IMAGES_TAG_DEST}"
      echo "-- Building Tomcat Base - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
    if [ "${BUILDBASE_AM}" == "true" ]; then
      echo "-> Building AM Base -  START"
      IMAGE_CODE_LOCATION="build/base-images/am-base"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "${CONTAINER_IMAGE_BASE_TOMCAT}" "${IMAGES_TAG_SRC}" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_BASE_AM}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}" "--add-host am:127.0.0.1"
      imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_BASE_AM}" "${IMAGES_TAG_DEST}"
      echo "-- Building AM Base - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
    if [ "${BUILDBASE_IG}" == "true" ]; then
      echo "-> Building IG Base -  START"
      IMAGE_CODE_LOCATION="build/base-images/ig-base"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "${CONTAINER_IMAGE_BASE_TOMCAT}" "${IMAGES_TAG_SRC}" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_BASE_IG}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}"
      imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_BASE_IG}" "${IMAGES_TAG_DEST}"
      echo "-- Building IG Base - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
    if [ "${BUILDBASE_FACT}" == "true" ]; then
      echo "-> Building FACT Base -  START"
      IMAGE_CODE_LOCATION="build/base-images/fact-base"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "${CONTAINER_IMAGE_BASE_AM}" "${IMAGES_TAG_SRC}" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_BASE_FACT}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}"
      imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_BASE_FACT}" "${IMAGES_TAG_DEST}"
      echo "-- Building FACT Base - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
    if [ "${BUILDBASE_DS}" == "true" ]; then
      echo "-> Building DS Base -  START"
      IMAGE_CODE_LOCATION="build/base-images/ds-base"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "${CONTAINER_IMAGE_BASE_JAVA}" "${IMAGES_TAG_SRC}" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_BASE_DS}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}"
      imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_BASE_DS}" "${IMAGES_TAG_DEST}"
      echo "-- Building DS Base - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
    if [ "${BUILDBASE_IDM}" == "true" ]; then
      echo "-> Building IDM Base -  START"
      IMAGE_CODE_LOCATION="build/base-images/idm-base"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "${CONTAINER_IMAGE_BASE_JAVA}" "${IMAGES_TAG_SRC}" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_BASE_IDM}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}"
      imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_BASE_IDM}" "${IMAGES_TAG_DEST}"
      echo "-- Building IDM Base - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
    if [ "${BUILDCHILD_RS}" == "true" ]; then
      echo "-> Building RS Child -  START"
      IMAGE_CODE_LOCATION="build/child-images/repl-server"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "${CONTAINER_IMAGE_BASE_DS}" "${IMAGES_TAG_SRC}" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_CHILD_RS}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}"
      imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_CHILD_RS}" "${IMAGES_TAG_DEST}"
      echo "-- Building RS Child - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
    if [ "${BUILDCHILD_APS}" == "true" ]; then
      echo "-> Building APS Child -  START"
      IMAGE_CODE_LOCATION="build/child-images/app-policy-store"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "${CONTAINER_IMAGE_BASE_DS}" "${IMAGES_TAG_SRC}" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_CHILD_APS}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}"
      imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_CHILD_APS}" "${IMAGES_TAG_DEST}"
      echo "-- Building APS Child - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
    if [ "${BUILDCHILD_TS}" == "true" ]; then
      echo "-> Building TS Child -  START"
      IMAGE_CODE_LOCATION="build/child-images/token-store"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "${CONTAINER_IMAGE_BASE_DS}" "${IMAGES_TAG_SRC}" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_CHILD_TS}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}"
      imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_CHILD_TS}" "${IMAGES_TAG_DEST}"
      echo "-- Building TS Child - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
    if [ "${BUILDCHILD_US}" == "true" ]; then
      echo "-> Building US Child -  START"
      IMAGE_CODE_LOCATION="build/child-images/user-store"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "${CONTAINER_IMAGE_BASE_DS}" "${IMAGES_TAG_SRC}" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_CHILD_US}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}"
      imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_CHILD_US}" "${IMAGES_TAG_DEST}"
      echo "-- Building US Child - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
    if [ "${BUILDCHILD_IDM}" == "true" ]; then
      echo "-> Building IDM Child -  START"
      IMAGE_CODE_LOCATION="build/child-images/idm"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "${CONTAINER_IMAGE_BASE_IDM}" "${IMAGES_TAG_SRC}" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_CHILD_IDM}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}"
      imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_CHILD_IDM}" "${IMAGES_TAG_DEST}"
      echo "-- Building IDM Child - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
    if [ "${BUILDCHILD_AM}" == "true" ]; then
      echo "-> Building AM Child -  START"
      IMAGE_CODE_LOCATION="build/child-images/access-manager"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "${CONTAINER_IMAGE_BASE_AM}" "${IMAGES_TAG_SRC}" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_CHILD_AM}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}"
      imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_CHILD_AM}" "${IMAGES_TAG_DEST}"
      echo "-- Building AM Child - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
    if [ "${BUILDCHILD_FACT}" == "true" ]; then
      echo "-> Building FACT -  START"
      IMAGE_CODE_LOCATION="build/child-images/fact"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "${CONTAINER_IMAGE_BASE_FACT}" "${IMAGES_TAG_SRC}" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_CHILD_FACT}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}"
      imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_CHILD_FACT}" "${IMAGES_TAG_DEST}"
      echo "-- Building FACT - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
    if [ "${BUILDCHILD_IG}" == "true" ]; then
      echo "-> Building IG Child -  START"
      IMAGE_CODE_LOCATION="build/child-images/ig"
      imageBuild "${BINARY_LOCATION}" "${STORAGE_BUCKET_PATH_BIN}" "${CONTAINER_IMAGE_BASE_IG}" "${IMAGES_TAG_SRC}" "${SFTP_UNAME}" "${SFTP_PWORD}" "${CONTAINER_IMAGE_CHILD_IG}" "${IMAGES_TAG_DEST}" "${IMAGE_CODE_LOCATION}"
      imageTest "${IMAGE_CODE_LOCATION}"
      imagePush "${CONTAINER_IMAGE_CHILD_IG}" "${IMAGES_TAG_DEST}"
      echo "-- Building IDM Child - END"
      echo " "
      sleep ${sleepTimerSecs}
    fi
  fi
  if [ "${errorFound}" == "true" ]; then
    echo "-- ERROR: Something went wrong. See above log for details. Exiting ..."
    exit 1
  fi
}

clear
case "${1}" in
  "login")
    logIntoContainerRegistry
    ;;
  "build")
    buildImages
    ;;
  *)
    echo "-- ERROR: Invalid input '${1}' provided to '$(basename \"$BASH_SOURCE\")'"
    ;;
esac