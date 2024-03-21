#!/usr/bin/env bash
# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

# Script to be executed by ForgeRock Directory Server(DS) Kubernetes container
# on startup to configure itself as a ForgeRock Directory Server (Applications
# Policies Store).

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
source "${DS_SCRIPTS}/forgerock-ds-shared-functions.sh"

# Local Variables
# ---------------
path_secretsRS="/opt/ds/secrets/rs"
path_secretsAM="/opt/ds/secrets/am"

setupOrStartDs "${BACKUP_BEFORE_UPGRADE}" "${LOAD_CUSTOM_DS_CONFIG}" "${LOAD_SCHEMA}" \
  "${LOAD_CUSTOM_JAVA_PROPS}" "${DISABLE_INSECURE_COMMS}" "${DN_BASE}" "${PORT_ADMIN}" "${DN_ADMIN}" \
  "${SECRET_PASSWORD_USER_ADMIN}" "${PROTOCOL_REST}" "${PORT_HTTPS}" "${DS_TYPE}"  "${CERT_ALIAS}"