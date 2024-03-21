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

# Image recommended name: forgerock-am-base
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
# Defaults
ARG ig_version_war="7.2.0"
ARG ig_version_zip="2023.11.0"
ARG igHome="/opt/ig"
ARG igUri="ig"
ARG path_tmp="/tmp/ig"
ARG filename_ig_war="IG-${ig_version_war}.war"
ARG filename_ig_zip="IG-${ig_version_zip}.zip"
ARG downloadPath_ig_war="${artifactory_baseUrl}/ping-identity/forgerock/identity-gateway/${filename_ig_war}"
ARG downloadPath_ig_zip="${artifactory_baseUrl}/ping-identity/forgerock/identity-gateway/${filename_ig_zip}"

# Environment Variables
# ---------------------
# IG_TYPE can be 'standalone' or 'tomcat'
# IG_INSTANCE_DIR is a ForgeRock variable name
ENV IG_HOME="${igHome}" \
    IG_URI="${igUri}" \
    CERT_ALIAS="ig" \
    IG_TYPE="standalone" \
    IG_MODE="PRODUCTION"
ENV SECRETS="${IG_HOME}/secrets" \
    CONFIGMAPS="${IG_HOME}/configmaps" \
    IG_INSTANCE_DIR="${IG_HOME}/instance" \
    DIR_KEYSTORES="${IG_HOME}/keystores" \
    DIR_SECRETSTORES="${IG_HOME}/secretstores" \
    CONFIG_BASE="${IG_HOME}/config-base"
ENV DIR_CONFIG="${IG_INSTANCE_DIR}/config"
ENV DIR_ROUTES="${DIR_CONFIG}/routes" \
    IG_KEYSTORE="${DIR_KEYSTORES}/keystore.p12"

# Setup default shell to Bash
# ---------------------------
SHELL ["/bin/bash", "-c"]

# Copy over configuration scripts
# -------------------------------
COPY setup.sh ${path_tmp}/

# Setting up the image
# --------------------
RUN echo "-> Setting scripts execution permistion" && \
    chmod +x ${path_tmp}/*.sh && \
    echo "-- Done" && echo " " && \
    "${path_tmp}/setup.sh"

EXPOSE 8080 80 8443 443