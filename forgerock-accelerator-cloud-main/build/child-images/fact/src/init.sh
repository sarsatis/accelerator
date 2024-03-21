#!/usr/bin/env bash
# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

# Script to be executed by Midships ForgeRock Accelerator Config Extractore
# on startup to configure itself.

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
# Local Variables
# ---------------
# BASH Colours
# Black        0;30     Dark Gray     1;30
# Red          0;31     Light Red     1;31
# Green        0;32     Light Green   1;32
# Brown/Orange 0;33     Yellow        1;33
# Blue         0;34     Light Blue    1;34
# Purple       0;35     Light Purple  1;35
# Cyan         0;36     Light Cyan    1;36
# Light Gray   0;37     White         1;37
color_red='\033[0;31m'
color_orange='\033[0;33m'
color_none='\033[0m'
errorFound="false"
path_tmpDir=

echo " ======================================================================= "
echo -e "|                  \
 ${color_red}F${color_none}${color_orange}ORGEROCK${color_none}\
 ${color_red}A${color_none}${color_orange}CCELERATOR${color_none}\
 ${color_red}C${color_none}${color_orange}ONFIG${color_none}\
 ${color_red}T${color_none}${color_orange}OOL${color_none}                  |"
echo " ---------------- Midships ForgeRock Accelerator - FACT --------------- "
echo ""
echo "   (F)orgerock (A)ccelerator (C)onfiguration (T)ool"
echo "->                  HOSTNAME: ${HOSTNAME}" NODE_VERSION
echo "->                  HOSTNAME: ${HOSTNAME}"
echo "->                 FACT_HOME: ${FACT_HOME}"
echo "->                TOOLS_HOME: ${TOOLS_HOME}"
echo "->                 DIFF_MODE: ${DIFF_MODE}"
echo "->                CONFIG_DIR: ${CONFIG_DIR}"
echo "->                  NODE_ENV: ${NODE_ENV}"
echo "->                      PORT: ${PORT}"
echo "->             POD_NAMESPACE: ${POD_NAMESPACE}"
echo "----------------------------------------------------------"
echo ""

echo "Checking Environment variables"
echo "------------------------------"
if [ -z "${NODE_ENV}" ] || [ "${NODE_ENV,,}" == "dev" ] || [[ "${ENV_TYPE,,}" == *"dev"* ]]; then
  export NODE_ENV="development"
else
  export NODE_ENV="production"
fi
echo "-- NODE_ENV set to '${NODE_ENV}'"

if [ -z "${DIFF_MODE}" ] || ([ "${DIFF_MODE}" != "am" ] && [ "${DIFF_MODE}" != "idm" ] && [ "${DIFF_MODE}" != "ig" ]); then
  echo "-- WARN: DIFF_MODE '${DIFF_MODE}' is either empty or value not allowed. Setting to 'am' by default."
  echo "   Allowed values are:"
  echo "   > 'am' for Access Manager"
  echo "   > 'idm' for Identity Manager"
  echo "   > 'ig' for Internet Gateway"
  export DIFF_MODE="am"
  echo ""
fi
echo "-- DIFF_MODE set to '${DIFF_MODE}'"

if [ ! -d "${FACT_HOME}" ]; then
  echo "-> ERROR: '${FACT_HOME}' does NOT exists."
  echo "-- Please check your Docker image build and confiirm path is correct."
  echo ""
  errorFound="true"
fi

counter=1
path_tmpDir="${CONFIG_DIR}/config-update-done"
echo "-> Checking if CONFIG_DIR '${path_tmpDir}' is available ..."
while [ ! -f "${path_tmpDir}" ]; do
  echo "-- Waitng 10 seconds ..."
  sleep 10
  if [ ${counter} -eq 30 ]; then
    echo "-- ERROR: Waited 5mins and file was not found."
    echo "   Check that '${CONFIG_DIR}' is mounted to the Pod."
    echo "   Exiting ..."
    exit 1
  fi
  counter=$((counter+1))
done
echo "-- Cleaning up ..."
rm -rf "${path_tmpDir}"
echo "-- Done"
echo ""

if [ -d "${CONFIG_DIR}" ]; then
  echo "-> Setting up pre-requisites for DIFF_MODE '${DIFF_MODE}'"
  case ${DIFF_MODE} in
    "am")
      path_tmpDir="${FACT_HOME}/base-config"
      echo "-- Creating Base directory '${path_tmpDir}'"
      mkdir -p "${path_tmpDir}"
      if [ ! -d "${path_tmpDir}" ]; then
        echo "-- ERROR: Something went wrong creating directory"
        errorFound="true"
        echo ""
      else
        echo "-- Done"
        echo ""
        echo "-- Listing Current Configs '${CONFIG_DIR}'"
        ls -ltra ${CONFIG_DIR}
        echo ""
        echo "-- Copying over Configs ..."
        cp -Rp ${CONFIG_DIR}/. ${path_tmpDir}/
        echo "-- Listing Base Configs '${path_tmpDir}'"
        ls -ltra ${path_tmpDir}/
        echo "-- Done";
        echo " ";
      fi
      ;;
    "idm")
      echo "-- ERROR: DIFF_MODE '${DIFF_MODE}'set for IDM. Feature not available."
      errorFound="true"
      ;;
    "IG")
      echo "-- ERROR: DIFF_MODE '${DIFF_MODE}' set for IG. Feature not available."
      errorFound="true"
      ;;
    *)
      echo "-- ERROR: Invalid DIFF_MODE '${DIFF_MODE}'"
      ;;
  esac
fi
echo "";
echo -e "[** Starting\
  ${color_red}F${color_none}${color_orange}ORGEROCK${color_none} \
  ${color_red}A${color_none}${color_orange}CCELERATOR${color_none} \
  ${color_red}C${color_none}${color_orange}ONFIG${color_none} \
  ${color_red}T${color_none}${color_orange}OOL${color_none} **]"
echo ""

if [ "${errorFound}" == "true" ]; then
  echo "-- ERROR: Somehting went wrong. See above logs. Exiting ..."
  exit 1
fi

echo "midships-fact-setup-done" > "${FACT_HOME}/fact-setup-done" # Notify startup probe

node bin/www