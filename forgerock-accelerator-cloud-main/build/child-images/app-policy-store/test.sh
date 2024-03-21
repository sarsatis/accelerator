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
# set -o nounset  # Don't allow unset variables
#set -o xtrace  # Enable debugging of the script, only do this in local dev as it prints secrets to the log

if [[ "${CI_REGISTRY_URL}" == *"local"* ]]; then
  source "$(git rev-parse --show-toplevel)/scripts/cicd/image-test-helpers.sh"
else
  source "${CI_PROJECT_DIR}/scripts/cicd/image-test-helpers.sh"
fi

image="${CI_REGISTRY_URL}/forgerock-app-policy-store:${IMAGES_TAG_SRC}"


declare -A env_checks=(
  ["CERT_ALIAS"]="app-policy-store"
  ["DS_CUSTOM_SCHEMA"]="/opt/ds/am-fbc-schema.ldif"
  ["DS_SECRETS"]="/opt/ds/secrets/aps"
  ["DS_TYPE"]="aps"
)

for var_name in "${!env_checks[@]}"; do
  inspect_image_environment "${image}" \
  "${var_name}=${env_checks[$var_name]}" \
  "PASSED - ${var_name} env var exists and set to ${env_checks[$var_name]}" \
  "FAILED - ${var_name} env var missing or not set to ${env_checks[$var_name]}"
done

inspect_image_user "${image}" \
  "ds" \
  "PASSED - User correctly set to 'ds'" \
  "FAILED - User not set to 'ds'"

test_entrypoint  ${image} '["bash","/opt/ds/scripts/init.sh"]'

check_test_results
