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

# Image recommended name: java-base
# ========================================================================

FROM debian:12.4-slim

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
ARG path_tmp="/tmp/java"
ARG midships_scripts_path="/opt/midships/scripts"
ARG java_version_major=11
ARG java_version_minor=22
ARG jdk_path="jdk-${java_version_major}.0.${java_version_minor}+7"
ARG filename_jdk="openjdk-${java_version_major}.0.${java_version_minor}_7_linux-x64_bin.tar.gz"
ARG downloadPath_jdk="${artifactory_baseUrl}/oracle/openjdk/${filename_jdk}"

# Environment Variables
# ---------------------
ENV JAVA_VERSION_MAJOR="${java_version_major}" \
    JAVA_VERSION_MINOR="${java_version_minor}" \
    MIDSHIPS_SCRIPTS="${midships_scripts_path}" \
    JVM_PATH="/usr/lib/jvm" \
    JDK_PATH="${jdk_path}"
ENV JAVA_HOME="${JVM_PATH}/${jdk_path}"
ENV PATH="$JAVA_HOME/bin:$PATH" \
    JAVA_CACERTS="${JAVA_HOME}/lib/security/cacerts"

# Setup default shell to Bash
# ---------------------------
SHELL ["/bin/bash", "-c"]

# Copy required files
# -------------------
COPY files/midshipscore.sh ${MIDSHIPS_SCRIPTS}/
COPY files/setup.sh ${path_tmp}/

# Setting up the base image
# -------------------------
RUN chmod +x ${path_tmp}/setup.sh
RUN ${path_tmp}/setup.sh

CMD ["java","-version"]
