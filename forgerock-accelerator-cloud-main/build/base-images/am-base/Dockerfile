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
ARG version_am=7.4.0
ARG version_amster=7.4.0
ARG amHome=/opt/am
ARG amUri=am
ARG path_tmp=/tmp/am
ARG path_tmpBin="${path_tmp}/bin"
ARG filename_am="AM-${version_am}.zip"
ARG filename_amster="Amster-${version_amster}.zip"
ARG artifactoryPath_am="ping-identity/forgerock/access-manager/${filename_am}"
ARG artifactoryPath_amster="ping-identity/forgerock/access-manager/tools/amster/${filename_amster}"
ARG downloadPath_am="${artifactory_baseUrl}/${artifactoryPath_am}"
ARG downloadPath_amster="${artifactory_baseUrl}/${artifactoryPath_amster}"

# Environment Variables
# ---------------------
# Version for Amster import if used
ENV VERSION="${version_amster}" \
    VERSION_AM="${version_am}"
ENV AM_HOME="${amHome}" \
    AM_URI="${amUri}"
ENV AM_PATH_SECRETS_IN_CLIENT="${AM_HOME}/secrets" \
    AM_PATH_SECURITY="${AM_HOME}/security" \
    AM_PATH_CONFIG="${AM_HOME}/config" \
    AM_PATH_CONFIG_BASE="${AM_HOME}/base/config"\
    AM_PATH_TOOLS="${AM_HOME}/tools"
ENV AMSTER_HOME="${AM_PATH_TOOLS}/amster" \
    AM_PATH_SECRETS_DEFAULT="${AM_PATH_SECURITY}/secrets/default" \
    AM_PATH_SECRETS_ENCRYPTED="${AM_PATH_SECURITY}/secrets/encrypted" \
    AM_PATH_SECRETS_AMSTER="${AM_PATH_SECURITY}/keys/amster" \
    AM_PATH_KEYSTORES="${AM_PATH_SECURITY}/keystores" \
    CERT_ALIAS="access-manager"
ENV CATALINA_OPTS="-server \
    -Dcom.sun.services.debug.mergeall=on \
    -Dcom.sun.identity.configuration.directory="${AM_HOME}" \
    -Dcom.iplanet.services.stats.state=off \
    -Dcom.sun.identity.sm.sms_object_filebased_enabled=true \
    -Dorg.forgerock.donotupgrade=true \
    -DtomcatAccessLogDir=/proc/self/fd -DtomcatAccessLogFile=1 \
    -Djava.security.egd=file:/dev/urandom"

# Copy over configuration scripts
# -------------------------------
COPY files/ ${path_tmp}/

# Setting up the image
# --------------------
RUN echo "-> Contents of '${path_tmp}'" && \
    ls -ltr ${path_tmp} && \
    echo "-- Done" && echo " " && \
    echo "-> Setting scripts execution permistion" && \
    chmod +x ${path_tmp}/scripts/*.sh && \
    echo "-- Done" && echo " " && \
    "${path_tmp}/scripts/01-setup-bin-and-user.sh" || exit 1

RUN echo "-> Setting permission(s)" && \
    chown -R am:forgerock ${AM_HOME} ${CATALINA_HOME} ${MIDSHIPS_SCRIPTS} ${JAVA_CACERTS} ${path_tmp} && \
    chmod -R u=rw,g=r,o=r "${JAVA_CACERTS}" && chmod -R +x ${CATALINA_HOME}/bin && \
    echo "-- Done" && echo " "

USER am
RUN ${path_tmp}/scripts/02-setup-install-components.sh || exit 1
EXPOSE 8443 443