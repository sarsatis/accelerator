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

# Image recommended name: forgerock-idm
# ========================================================================

ARG image_tag="<default-image-tag>"
ARG image_src="<container-registry-base-image-path>"
FROM ${image_src}:${image_tag}

# Copy over files
# ---------------
COPY --chown=idm:forgerock files/forgerock-idm-shared-functions.sh ${IDM_HOME}/scripts/
COPY --chown=idm:forgerock files/init.sh ${IDM_HOME}/scripts/
COPY --chown=idm:forgerock files/config-base ${CONFIG_BASE}

USER idm
EXPOSE 8443 443 8080 80

ENTRYPOINT ["bash", "/opt/idm/scripts/init.sh"]
