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

# Image recommended name: forgerock-ds-base
# ========================================================================

ARG image_tag="<default-image-tag>"
ARG image_src="<container-registry-base-image-path>"
FROM ${image_src}:${image_tag}

# Setting user to root to allow privileged commands like chmod, chown to run during Docker builld.
# This is a base image and is never deployed directly to the k8s cluster.
# Is is the foundation for all child images. The non previledge user is set in the child images.
USER root


# Arguments
# ---------
# artifactory_source values 'sftp', 'gcp', 'aws'
# artifactory_baseUrl: For example 'gs://ready-to-integrate/bin'
ARG artifactory_source=""
ARG artifactory_baseUrl=""
ARG artifactory_uname=""
ARG artifactory_pword=""
# Defaults:
ARG ds_version=7.4.0
ARG ds_home=/opt/ds
ARG path_tmp=/tmp/ds
ARG filename_ds="DS-${ds_version}.zip"
ARG downloadPath_ds="${artifactory_baseUrl}/ping-identity/forgerock/directory-services/${filename_ds}"

# Environment Variables
# ---------------------
ENV DS_HOME="${ds_home}" \
  	DS_APP="${ds_home}/app" \
    DS_INSTANCE="${ds_home}/app/instance" \
    DS_SCRIPTS="${ds_home}/scripts" \
    DS_SECRETS="${ds_home}/secrets" \
    DS_VERSION="${ds_version}" \
    DS_VERSION_PATH="${ds_home}/app/version.txt" \
    DS_FILENAME="${filename_ds}" \
    OPENDJ_JAVA_HOME="${JAVA_HOME}" \
    CERT_ALIAS="directory-server" \
    DS_CUSTOM_SCHEMA="${ds_home}/custom-schema.ldif"

# Setup default shell to Bash
# ---------------------------
SHELL ["/bin/bash", "-c"]

# Copy over scripts
# -----------------
COPY files/forgerock-ds-shared-functions.sh ${DS_SCRIPTS}/
COPY files/setup.sh ${path_tmp}/

# Setting up the image
# --------------------
RUN chmod +x ${path_tmp}/setup.sh 
RUN ${path_tmp}/setup.sh

EXPOSE 8443 1636 4444
