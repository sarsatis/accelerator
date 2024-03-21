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

# Image recommended name: tomcat-base
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
ARG tomcat_version=9.0.85
ARG path_tmp=/tmp/tomcat
ARG tomcat_dir=/opt/tomcat
ONBUILD ARG tomcat_dir=/opt/tomcat
ARG filename_tomcat="apache-tomcat-${tomcat_version}.zip"
ARG downloadPath_tomcat="${artifactory_baseUrl}/apache/tomcat/${filename_tomcat}"

# Environment Variables
# ---------------------
ENV TOMCAT_HOME="${tomcat_dir}" \
    CATALINA_HOME="${tomcat_dir}/apache-tomcat-${tomcat_version}"
ENV CATALINA_PID="${CATALINA_HOME}/catalina.pid" \
    CATALINA_JKS="${CATALINA_HOME}/tomcat.jks"

# Copy over configuration scripts
# -------------------------------
COPY files/tomcat-shared-functions.sh ${MIDSHIPS_SCRIPTS}/
COPY files/setup.sh ${path_tmp}/

# Setting up the image
# --------------------
RUN chmod +x ${path_tmp}/setup.sh
RUN ${path_tmp}/setup.sh

EXPOSE 8443
