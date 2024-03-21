#!/usr/bin/env bash
# KEY VARIABLES
# NOTE: All variables available in the docker entrypoint are available here
# -------------------------------------------------------------------------
# ${svcURL_curr} : server FQDN
# ${adminConnectorPort} : DS Ad in Port
# ${rootUserDN} : DS Root User DN
# ${rootUserPassword} : DS Root User Password
# ${DS_APP}/bin/ : DS bin directory
# ${ldapsPort} : DS LDAPS port

echo "Executing Directory Services (DS) Custom Config Script"
echo "------------------------------------------------------"
echo ""
# echo "-> Configuring index for custom attributes"
# backendName="userStore"
# ${DS_APP}/bin/dsconfig  create-backend-index  --hostname "${svcURL_curr}" --port ${adminConnectorPort}  --bindDN "${rootUserDN}"  --bindPassword "${rootUserPassword}" --backend-name ${backendName} --index-name cif  --set index-type:equality  --trustAll  --no-prompt
# ${DS_APP}/bin/dsconfig  create-backend-index  --hostname "${svcURL_curr}" --port ${adminConnectorPort}  --bindDN "${rootUserDN}"  --bindPassword "${rootUserPassword}" --backend-name ${backendName} --index-name customerId  --set index-type:equality  --trustAll  --no-prompt
# ${DS_APP}/bin/dsconfig  create-backend-index  --hostname "${svcURL_curr}" --port ${adminConnectorPort}  --bindDN "${rootUserDN}"  --bindPassword "${rootUserPassword}" --backend-name ${backendName} --index-name ktp  --set index-type:equality  --trustAll  --no-prompt
# echo "-- Done"
# echo ""
