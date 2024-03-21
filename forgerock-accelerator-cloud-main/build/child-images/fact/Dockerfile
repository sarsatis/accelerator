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

# Image recommended name: midships-fact
# ===========================================================

ARG image_tag="<default-image-tag>"
ARG image_src="<container-registry-base-image-path>"
FROM ${image_src}:${image_tag}

# Environment Variables
ENV FACT_HOME="/opt/fact" \
    PORT=8082

# Create app directory
WORKDIR "${FACT_HOME}"

RUN echo "-> Checking key ENV Variables" && \
    echo "-- FACT_HOME is ${FACT_HOME}" && \
    echo "-- NODE_HOME is ${NODE_HOME}" && \
    echo "-- TOOLS_HOME is ${TOOLS_HOME}" && \
    echo "-- JAVA_CACERTS is ${JAVA_CACERTS}" && \
    echo "-- Done" && echo "";

# Copy over files
COPY --chown=am:forgerock . .
COPY --chown=am:forgerock package*.json ./

RUN echo "-> Installing Application dependencies" && \
    npm ci --omit=dev && echo "-- Done" && echo "" && \
    echo "-> Setting permission(s)" && \
    chown -R am:forgerock "${NODE_HOME}" "${FACT_HOME}" "${JAVA_CACERTS}" "${TOOLS_HOME}" && \
    chmod -R u=rwx,g=rx,o=r "${FACT_HOME}" "${JAVA_CACERTS}" "${TOOLS_HOME}" && \
    echo "-- Done" && echo ""

USER am

EXPOSE ${8082}

ENTRYPOINT ["bash", "/opt/fact/src/init.sh"]
