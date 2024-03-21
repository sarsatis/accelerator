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

# Image recommended name:
#  - forgerock-repl-server-us for replicating user stores
#  - forgerock-repl-server-ts for replicating token stores
# ===========================================================

ARG image_tag="<default-image-tag>"
ARG image_src="<container-registry-base-image-path>"
FROM ${image_src}:${image_tag}

ENV CERT_ALIAS="repl-server" \
    DS_SECRETS="${DS_SECRETS}/rs" \
    DS_TYPE="rs"

USER ds

# Setup configuration scripts
# ---------------------------
COPY files/*.sh ${DS_SCRIPTS}/
COPY files/*.properties ${DS_HOME}/

ENTRYPOINT ["bash", "/opt/ds/scripts/init.sh"]
