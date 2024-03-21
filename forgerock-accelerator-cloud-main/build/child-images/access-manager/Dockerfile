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

# Image recommended name: forgerock-access-manager
# ========================================================================

ARG image_tag="<default-image-tag>"
ARG image_src="<container-registry-base-image-path>"
FROM ${image_src}:${image_tag}

ARG artifactory_source=""
ARG artifactory_baseUrl=""
ARG artifactory_uname=""
ARG artifactory_pword=""
ARG path_tmp="/tmp/am"
ARG downloadPath_jar=""
# "${artifactory_baseUrl}/ping-identity/forgerock/access-manager/midships/qr-code-node-1.0.jar"

ENV CERT_ALIAS="access-manager"

USER am
RUN mkdir -p "${path_tmp}"

# Copy over configuration scripts
# -------------------------------
COPY --chown=am:forgerock files/scripts/forgerock-am-shared-functions.sh ${AM_HOME}/scripts/
COPY --chown=am:forgerock files/scripts/remove-app-policies.amster ${AM_HOME}/scripts/
COPY --chown=am:forgerock files/scripts/init.sh ${AM_HOME}/scripts/
COPY --chown=am:forgerock files/config/amster ${AM_PATH_CONFIG}/amster
COPY --chown=am:forgerock files/config/services ${AM_PATH_CONFIG}/services
COPY --chown=am:forgerock files/config/*.xml ${AM_PATH_CONFIG}/
COPY --chown=am:forgerock files/scripts/setup.sh ${path_tmp}/

RUN chmod +x ${path_tmp}/*.sh
RUN ${path_tmp}/setup.sh

EXPOSE 8443 443 8080 80

ENTRYPOINT ["bash", "/opt/am/scripts/init.sh"]
