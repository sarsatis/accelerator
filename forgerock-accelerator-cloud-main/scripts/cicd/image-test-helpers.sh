#!/usr/bin/env bash

# file intended to be sourced and not used directly
set -o posix

declare -A succeeded_tests
declare -A failed_tests

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
color_green='\033[0;32m'
color_none='\033[0m'

# Execute a command in an image and if the command exits with an exit code of 0 (success) then store
# the success_message value in the succeeded_tests associative array and store the failed_message value in the
# failed_tests associative array
function execute_command_in_image() {
  image_name="${1}"
  command="${2}"
  success_message="${3}"
  failure_message="${4}"
  search_string="${5}"

  if docker run "${image}" /bin/bash -c "${command}"; then
      succeeded_tests+=([${search_string}]=${success_message})
  else
      failed_tests+=([${search_string}]=${failure_message})
  fi
}

function inspect_image_environment() {
  image_name="${1}"
  search_string="${2}"
  success_message="${3}"
  failure_message="${4}"

  # TODO - improve this using jq instead of grep
  if docker inspect "${image_name}" | grep "${search_string}" > /dev/null; then
    succeeded_tests+=([${search_string}]=${success_message})
  else
    failed_tests+=([${search_string}]=${failure_message})
  fi
}

function inspect_image_user() {
  image_name="${1}"
  expected_user_name="${2}"
  success_message="${3}"
  failure_message="${4}"

  image_user_name=$(docker inspect "${image_name}" | jq --raw-output '.[].Config.User')
  if [[ "${image_user_name}" == "${expected_user_name}" ]]; then
    succeeded_tests+=([${expected_user_name}]=${success_message})
  else
    failed_tests+=([${expected_user_name}]=${failure_message})
  fi
}

# Inspect the port configuration of the container and validate it against an array of ports
# Note the arrays of ports must be the last argument due to how bash handles array arguments (badly)
#
# arg1 - image name - e.g. /local/java-base
# arg2 - success message - e.g. "PASSED"
# arg3 - failure message - e.g. "FAILED"
# arg4 - array of integers - e.g. (80 443)
function inspect_exposed_port_configuration() {
  image_name="${1}"
  shift
  success_message="${1}"
  shift
  failure_message="${1}"
  shift
  expected_ports=("$@")

  exposed_ports=$(docker inspect "${image_name}" | jq --raw-output '.[].Config.ExposedPorts')
  port_missing=false

  for port in "${expected_ports[@]}"; do
    if [ ${?} -ne 0 ]; then
      port_missing=true
    fi
  done

  if [[ "${port_missing}" == "false" ]]; then
    succeeded_tests+=([${expected_ports[*]}]=${success_message})
  else
    failed_tests+=([${expected_ports[*]}]=${failure_message})
  fi
}

# Echo the success then failure messages stored in the associative arrays declared above
# Exit the script with code 1 if any test failures exist
function check_test_results() {
  local failures_exist="false"
  for key in "${!succeeded_tests[@]}"; do
    echo -e "${succeeded_tests[$key]}"
  done
  for key in "${!failed_tests[@]}"; do
    echo -e "${failed_tests[$key]} -- failed expectation was: ${key}"
    failures_exist="true"
  done

  if [ "${failures_exist}" == "true" ]; then
    echo -e "${color_red}IMAGE TEST FAILURES EXIST - PLEASE CHECK THE IMAGE AND REBUILD ${color_none} "
    exit 1
  else
    echo -e "${color_green}All image tests passed ${color_none} "
  fi
}


test_entrypoint() {
    local image_name=$1
    local expected_entrypoint=$2
    local success_message="PASSED - "
    local failure_message="FAILED - "
    
    local entrypoint=$(docker inspect --format='{{json .Config.Entrypoint}}' "$image_name")

    if [ "$entrypoint" != "$expected_entrypoint" ]; then
        failure_message+="Entrypoint for image $image_name is not as expected. Got : '$entrypoint'  . "
        failed_tests+=([${expected_entrypoint}]=${failure_message})
    
    else    
        success_message+="Entrypoint for image $image_name is  as expected."
        succeeded_tests+=([${expected_entrypoint}]=${success_message})
    fi
}


function inspect_image_working_dir() {
  image_name="${1}"
  search_string="${2}"
  success_message="${3}"
  failure_message="${4}"

  # TODO - improve this using jq instead of grep
  if docker inspect  "${image_name}" | jq -r '.[0].Config.WorkingDir' > /dev/null; then
    succeeded_tests+=([${search_string}]=${success_message})
  else
    failed_tests+=([${search_string}]=${failure_message})
  fi
}