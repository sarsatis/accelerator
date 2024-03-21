#!/usr/bin/env bash
# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

# Script to support the execution of the ForgeRock Access Management
# Kubernetes container on startup.

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
# Inherit Midhsips shared functions
source "${MIDSHIPS_SCRIPTS}/midshipscore.sh"

# ----------------------------------------------------------------------------------
# This function manages the Tomcat web container
#
# Parameters:
#  - ${1}: Tomcat Operation to perform
#       > "stop" : To Stop Tomcat
#       > "start-debug" : Start Tomcat in the background
#       > "start" : Start Tomcat in the forgeground
#  - "{2}: Access Manager server URL"
# ----------------------------------------------------------------------------------
function manageTomcat() {
  local tomcatCmd=${1}
  local amServerUrl=${2}

  if [ -z "${amServerUrl}" ] && [ "${tomcatCmd}" != "start-async" ] && [ "${tomcatCmd}" != "start" ]; then
    echo "-- ERROR: amServerUrl is empty. Please resolve and retest."
    exit 1
  fi
  case ${tomcatCmd} in
    "stop")
      echo "-> Stopping Tomcat"
      echo "   serverUrl: ${amServerUrl}"
      ${CATALINA_HOME}/bin/catalina.sh stop
      checkServerIsAlive --svc "${amServerUrl}" --type "url" --resCodeExpected "000"
      tomcatCheckCounter=1
      checkFrequency=5
      noOfChecks=6
      responseActual="waiting"
      echo ""
      echo "-- Confirming Tomcat process has stopped successfully"
      while [[ ${responseActual} > /dev/null ]];
      do
        responseActual=$(ps -ef | grep tomcat | grep java | awk ' { print $2 } ')
        echo "   Returned Tomcat Process ID is: ${responseActual}"
        echo -n "-- (${tomcatCheckCounter}/${noOfChecks}) Waiting ${checkFrequency} seconds ..."
        sleep ${checkFrequency}
        if [ ${tomcatCheckCounter} == ${noOfChecks} ]; then
          secondsWaitedFor=$((${checkFrequency} * ${noOfChecks}))
          echo ""
          echo "-- Waited for ${secondsWaitedFor} seconds and NO valid response"
          echo "-- WARN: Tomcat could still be running"
          if [[ "${responseActual}" -ge 0 ]]; then
            echo "-- killing Tomcat process (${responseActual})"
            kill -9 ${responseActual}
          fi
          echo "-- Done"
          echo ""
          return
        fi
        tomcatCheckCounter=$((${tomcatCheckCounter} + 1))
      done
      echo "   Tomcat stopped successfully"
      echo "-- Done"
      echo ""
    ;;
    "start-debug")
      echo "-> Starting Tomcat"
      echo "   serverUrl: ${amServerUrl}"
      ${CATALINA_HOME}/bin/catalina.sh jpda start
      checkServerIsAlive --svc "${amServerUrl}" --type "url" --resCodeExpected "302"
      echo "-- Tomcat started successfully (debug)"
      echo "-- Done"
      echo ""
    ;;
    "start-async")
      echo "-> Starting Tomcat"
      ${CATALINA_HOME}/bin/catalina.sh jpda start
      echo "-- Tomcat started successfully (async)"
      echo "-- Done"
      echo ""
    ;;
    "start")
      echo "-> Starting Tomcat"
      ${CATALINA_HOME}/bin/catalina.sh run –security
      ;;
  esac
}