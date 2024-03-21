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

# Image recommended name: forgerock-ig
# ===========================================================
ARG image_tag="<default-image-tag>"
ARG image_src="<container-registry-base-image-path>"
FROM ${image_src}:${image_tag}

ARG artifactory_source=""
ARG artifactory_baseUrl=""
ARG artifactory_uname=""
ARG artifactory_pword=""
ARG path_tmp="/tmp/ig"
ARG filename_jar="sample-file.jar"
ARG downloadPath_jarsDir="${artifactory_baseUrl}/ping-identity/forgerock/identity-gateway/midships"
ARG downloadPath_jars="${downloadPath_jarsDir}/*.jar"
ARG downloadPath_jar="${downloadPath_jarsDir}/${filename_jar}"

USER ig

# Copy over configuration scripts
# -------------------------------
COPY --chown=ig:forgerock files/config-base ${CONFIG_BASE}
COPY files/init.sh ${IG_HOME}/scripts/

EXPOSE 8443 443

ENTRYPOINT ["bash", "/opt/ig/scripts/init.sh"]