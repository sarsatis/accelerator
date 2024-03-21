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

set -o pipefail # Propagate piped command exit status codes to the main script
#set -o nounset  # Don't allow unset variables
#set -o xtrace  # Enable debugging of the script, only do this in local dev as it prints secrets to the log

if [[ "${CI_REGISTRY_URL}" == *"local"* ]]; then
  source "$(git rev-parse --show-toplevel)/scripts/cicd/image-test-helpers.sh"
else
  source "${CI_PROJECT_DIR}/scripts/cicd/image-test-helpers.sh"
fi

image="${CI_REGISTRY_URL}/forgerock-ds-base:${IMAGES_TAG_SRC}"

execute_command_in_image "${image}" \
  "ls -la /opt/ds > /dev/null" \
  "PASSED - /opt/ds folder present in image" \
  "FAILED - /opt/ds folder missing from image" \
  "ds_installation"

execute_command_in_image "${image}" \
  "env | grep DS_HOME > /dev/null" \
  "PASSED - DS_HOME env var exists" \
  "FAILED - DS_HOME env var missing" \
  "ds_home"

check_test_results
