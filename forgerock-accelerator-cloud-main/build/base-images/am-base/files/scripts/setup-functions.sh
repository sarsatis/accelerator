#!/usr/bin/env bash
# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

# This file contains scripts to configure the ForgeRock Access Manager
# (AM) image required by the Midships ForgeRock Accelerator.

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
# ========================================================================

# ----------------------------------------------------------------------------------
# NOTE: The below function template was taken from ForgeRock ForgeOps repo
#       https://github.com/ForgeRock/forgeops
# Parameters:
#  - ${1}: AM serverURL
#  - "{2}: Cookie file path"
# ----------------------------------------------------------------------------------
configure-external-datastores() {
  local httpCode="000"
  local serverURL="${1}"
  local path_amCookieFile="${2}"

  echo "[ SETUP EXTERNAL DATASOURCES ]"
  echo " "

  if [ -z "${serverURL}" ]; then
    echo "-- ERROR: AM server URL is EMPTY"
    errorFound="true"
  fi

  if [ ! -f "${path_amCookieFile}" ]; then
    echo "-- ERROR: Cookie file '${path_amCookieFile}' NOT found"
    errorFound="true"
  fi

  if [ "${errorFound}" == "true" ]; then
    echo "-- ERROR: Cookie file '${path_amCookieFile}' NOT found. Exiting ..."
    exit 1
  fi
  
  echo "-> Setup Base URL Service"
  httpCode=$(curl -sk -o /dev/null -w "%{http_code}" \
    "${serverURL}/json/global-config/services/baseurl" \
    -X PUT -b "${path_amCookieFile}" \
    -H "Accept-API-Version: protocol=1.0,resource=1.0" \
    -H "Content-Type: application/json" \
    --data-binary "{
      \"defaults\": {
        \"source\": \"FIXED_VALUE\"
      }
    }"
  )
  if [[ ${httpCode} -ne 200 ]]; then
    echo -e "\e[31m--Failed to set Base Url Service source attribute value.\e[0m"
    echo "-- HTTP Code returend: ${httpCode}"
    exit 1
  fi
  echo "-- Done"
  echo " "

  echo "-> Setup Eternal Application Store"
  if [ $(ver ${VERSION_AM}) -lt $(ver 7.4.0) ]; then
    echo "   For AM versions BELOW 7.4"
    httpCode=$(curl -sk -o /dev/null -w "%{http_code}" \
      "${serverURL}/json/global-config/services/DataStoreService/config?_action=create" \
      -X POST -H "Accept-API-Version: protocol=1.0,resource=1.0" \
      -H "Content-Type: application/json" -b "${path_amCookieFile}" \
      --data-binary "{
        \"_id\" : \"application-store\",
        \"bindDN\" : \"uid=admin\",
        \"bindPassword\" : \"password\",
        \"affinityEnabled\" : true,
        \"useStartTLS\" : false,
        \"serverUrls\" : [ \"localhost:50636\" ],
        \"minimumConnectionPool\" : 1,
        \"maximumConnectionPool\" : 80,
        \"useSsl\" : true
      }"
    )
  else
    echo "   For AM versions 7.4 and ABOVE"
    httpCode=$(curl -sk -o /dev/null -w "%{http_code}" \
      "${serverURL}/json/global-config/services/DataStoreService/config?_action=create" \
      -X POST -H "Accept-API-Version: protocol=1.0,resource=1.0" \
      -H "Content-Type: application/json" -b "${path_amCookieFile}" \
      --data-binary "{
        \"_id\" : \"application-store\",
        \"bindDN\" : \"uid=admin\",
        \"bindPassword\" : \"password\",
        \"dataStoreEnabled\" : true,
        \"affinityEnabled\" : true,
        \"mtlsEnabled\" : false,
        \"useStartTLS\" : false,
        \"serverUrls\" : [ \"localhost:50636\" ],
        \"minimumConnectionPool\" : 1,
        \"maximumConnectionPool\" : 80,
        \"useSsl\" : true
      }"
    )
  fi
  if [[ ${httpCode} -ne 201 ]]; then
    echo -e "\e[31m--Failed to create external application store.\e[0m"
    echo "-- HTTP Code returend: ${httpCode}"
    exit 1
  fi
  echo "-- Done"
  echo " "

  echo "-> Setup Eternal Policy Store"
  if [ $(ver ${VERSION_AM}) -lt $(ver 7.4.0) ]; then
    echo "   For AM versions BELOW 7.4"
    httpCode=$(curl -sk -o /dev/null -w "%{http_code}" \
      "${serverURL}/json/global-config/services/DataStoreService/config?_action=create" \
      -X POST -H "Accept-API-Version: protocol=1.0,resource=1.0" \
      -H "Content-Type: application/json" -b "${path_amCookieFile}" \
      --data-binary "{
        \"_id\" : \"policy-store\",
        \"bindDN\" : \"uid=admin\",
        \"bindPassword\" : \"password\",
        \"affinityEnabled\" : true,
        \"useStartTLS\" : false,
        \"serverUrls\" : [ \"localhost:50636\" ],
        \"minimumConnectionPool\" : 1,
        \"maximumConnectionPool\" : 80,
        \"useSsl\" : true
      }"
    )
  else
    echo "   For AM versions 7.4 and ABOVE"
    httpCode=$(curl -sk -o /dev/null -w "%{http_code}" \
      "${serverURL}/json/global-config/services/DataStoreService/config?_action=create" \
      -X POST -H "Accept-API-Version: protocol=1.0,resource=1.0" \
      -H "Content-Type: application/json" -b "${path_amCookieFile}" \
      --data-binary "{
        \"_id\" : \"policy-store\",
        \"bindDN\" : \"uid=admin\",
        \"bindPassword\" : \"password\",
        \"dataStoreEnabled\" : true,
        \"affinityEnabled\" : true,
        \"mtlsEnabled\" : false,
        \"useStartTLS\" : false,
        \"serverUrls\" : [ \"localhost:50636\" ],
        \"minimumConnectionPool\" : 1,
        \"maximumConnectionPool\" : 80,
        \"useSsl\" : true
      }"
    )
  fi
  if [[ ${httpCode} -ne 201 ]]; then
    echo -e "\e[31m--Failed to create external policy store.\e[0m"
    echo "-- HTTP Code returend: ${httpCode}"
    exit 1
  fi
  echo "-- Done"
  echo " "

  echo "-> Setup Default Realm Policy Configuration"
  httpCode=$(curl -sk -o /dev/null -w "%{http_code}" \
    "${serverURL}/json/global-config/services/policyconfiguration" \
    -X 'PUT' -H 'Accept-API-Version: protocol=1.0,resource=1.0' \
    -H 'Content-Type: application/json' -b "${path_amCookieFile}" \
    --data-binary "{
      \"defaults\":{
        \"policyHeartbeatInterval\":10,
        \"usersBaseDn\":\"ou=am-config\",
        \"checkIfResourceTypeExists\":true,
        \"maximumSearchResults\":100,
        \"connectionPoolMaximumSize\":80,
        \"searchTimeout\":5,
        \"subjectsResultTTL\":10,
        \"sslEnabled\":true,
        \"ldapServer\":[ \"localhost:50636\" ],
        \"usersSearchAttribute\":\"uid\",
        \"usersSearchFilter\":\"(objectclass=inetorgperson)\",
        \"connectionPoolMinimumSize\":1,
        \"realmSearchFilter\":\"(objectclass=sunismanagedorganization)\",
        \"policyHeartbeatTimeUnit\":\"SECONDS\",
        \"bindDn\":\"uid=am-config,ou=admins,ou=am-config\",
        \"userAliasEnabled\":false,
        \"usersSearchScope\":\"SCOPE_SUB\"
      },
      \"resourceComparators\":[\"serviceType=iPlanetAMWebAgentService|class=com.sun.identity.policy.plugins.HttpURLResourceName|wildcard=*|oneLevelWildcard=-*-|delimiter=/|caseSensitive=false\"],
      \"continueEvaluationOnDeny\":false,
      \"realmAliasReferrals\":false
    }"
  )
  if [[ ${httpCode} -ne 200 ]]; then
    echo -e "\e[31m--Failed to create default Realm Policy Configuration.\e[0m"
    echo "-- HTTP Code returend: ${httpCode}"
    exit 1
  fi
  echo "-- Done"
  echo " "

  echo "-> Map Eternal Application and Policy Stores"
  httpCode=$(curl -sk -o /dev/null -w "%{http_code}" \
    "${serverURL}/json/global-config/services/DataStoreService" \
    -X PUT -H "Accept-API-Version: protocol=1.0,resource=1.0" \
    -H "Content-Type: application/json" -b "${path_amCookieFile}" \
    --data-binary "{
      \"defaults\": {
        \"policyDataStoreId\": \"policy-store\",
        \"applicationDataStoreId\": \"application-store\"
      }
    }"
  )
  if [[ ${httpCode} -ne 200 ]]; then
    echo -e "\e[31m--Failed to set external application/policy store.\e[0m"
    echo "-- HTTP Code returend: ${httpCode}"
    exit 1
  fi
  echo "-- Done"
  echo " "

  echo "-> Create External Data Store Service in Root Realm"
  httpCode=$(curl -sk -o /dev/null -w "%{http_code}" \
    "${serverURL}/json/realms/root/realm-config/services/DataStoreService?_action=create" \
    -X POST -H "Accept-API-Version: protocol=1.0,resource=1.0" \
    -H "Content-Type: application/json" -b "${path_amCookieFile}" \
    --data-binary "{
      \"applicationDataStoreId\": \"application-store\",
      \"policyDataStoreId\": \"policy-store\"
    }"
  )
  if [[ ${httpCode} -ne 201 ]]; then
    echo -e "\e[31mFailed to create root realm external datastore service.\e[0m"
    exit 1
  fi
  echo "-- Done"
  echo " "

  echo "-> Setup Eternal Token Store"
  httpCode=$(curl -sk -o /dev/null -w "%{http_code}" \
    "${serverURL}/json/global-config/servers/server-default/properties/cts" \
    -X PUT -H "Accept-API-Version: protocol=1.0,resource=1.0" \
    -H "Content-Type: application/json" -b "${path_amCookieFile}" \
    --data-binary "{
      \"amconfig.org.forgerock.services.cts.store.common.section\": {
        \"org.forgerock.services.cts.store.location\": \"external\",
        \"org.forgerock.services.cts.store.root.suffix\": \"ou=tokens\",
        \"org.forgerock.services.cts.store.max.connections\": \"80\",
        \"org.forgerock.services.cts.store.page.size\": 0,
        \"org.forgerock.services.cts.store.vlv.page.size\": 1000
      },
      \"amconfig.org.forgerock.services.cts.store.external.section\": {
        \"org.forgerock.services.cts.store.ssl.enabled\": true,
        \"org.forgerock.services.cts.store.directory.name\": \"ds.localtest.me:50636\",
        \"org.forgerock.services.cts.store.loginid\": \"uid=admin\",
        \"org.forgerock.services.cts.store.password\": \"password\",
        \"org.forgerock.services.cts.store.heartbeat\": \"10\",
        \"org.forgerock.services.cts.store.affinity.enabled\": true
      }
    }"
  )
  if [[ ${httpCode} -ne 200 ]]; then
    echo -e "\e[31m--Failed to set external CTS store.\e[0m"
    echo "-- HTTP Code returend: ${httpCode}"
    exit 1
  fi
  echo "-- Done"
  echo " "

  echo "-> Setup Eternal UMA Store"
  httpCode=$(curl -sk -o /dev/null -w "%{http_code}" \
    "${serverURL}/json/global-config/servers/server-default/properties/uma" \
    -X PUT -b "${path_amCookieFile}" \
    -H "Accept-API-Version: protocol=1.0,resource=1.0" \
    -H "Content-Type: application/json" \
    --data-binary "{
      \"amconfig.org.forgerock.services.resourcesets.store.common.section\": {
        \"org.forgerock.services.resourcesets.store.location\": \"external\",
        \"org.forgerock.services.resourcesets.store.root.suffix\": \"ou=am-config\",
        \"org.forgerock.services.resourcesets.store.max.connections\": \"80\"
      },
      \"amconfig.org.forgerock.services.resourcesets.store.external.section\": {
        \"org.forgerock.services.resourcesets.store.ssl.enabled\": \"false\",
        \"org.forgerock.services.resourcesets.store.directory.name\": \"ds.localtest.me:1389\",
        \"org.forgerock.services.resourcesets.store.loginid\": \"uid=admin\",
        \"org.forgerock.services.resourcesets.store.password\": \"password\",
        \"org.forgerock.services.resourcesets.store.heartbeat\": \"10\"
      },
      \"amconfig.org.forgerock.services.umaaudit.store.common.section\": {
        \"org.forgerock.services.umaaudit.store.location\": \"external\",
        \"org.forgerock.services.umaaudit.store.root.suffix\": \"ou=am-config\",
        \"org.forgerock.services.umaaudit.store.max.connections\": \"80\"
      },
      \"amconfig.org.forgerock.services.umaaudit.store.external.section\": {
        \"org.forgerock.services.umaaudit.store.ssl.enabled\": \"false\",
        \"org.forgerock.services.umaaudit.store.directory.name\": \"ds.localtest.me:1389\",
        \"org.forgerock.services.umaaudit.store.loginid\": \"uid=admin\",
        \"org.forgerock.services.umaaudit.store.password\": \"password\",
        \"org.forgerock.services.umaaudit.store.heartbeat\": \"10\"
      },
      \"amconfig.org.forgerock.services.uma.pendingrequests.store.common.section\": {
        \"org.forgerock.services.uma.pendingrequests.store.location\": \"external\",
        \"org.forgerock.services.uma.pendingrequests.store.root.suffix\": \"ou=am-config\",
        \"org.forgerock.services.uma.pendingrequests.store.max.connections\": \"80\"
      },
      \"amconfig.org.forgerock.services.uma.pendingrequests.store.external.section\": {
        \"org.forgerock.services.uma.pendingrequests.store.ssl.enabled\": \"false\",
        \"org.forgerock.services.uma.pendingrequests.store.directory.name\": \"ds.localtest.me:1389\",
        \"org.forgerock.services.uma.pendingrequests.store.loginid\": \"uid=admin\",
        \"org.forgerock.services.uma.pendingrequests.store.password\": \"password\",
        \"org.forgerock.services.uma.pendingrequests.store.heartbeat\": \"10\"
      },
      \"amconfig.org.forgerock.services.uma.labels.store.common.section\": {
        \"org.forgerock.services.uma.labels.store.location\": \"external\",
        \"org.forgerock.services.uma.labels.store.root.suffix\": \"ou=am-config\",
        \"org.forgerock.services.uma.labels.store.max.connections\": \"80\"
      },
      \"amconfig.org.forgerock.services.uma.labels.store.external.section\": {
        \"org.forgerock.services.uma.labels.store.ssl.enabled\": \"false\",
        \"org.forgerock.services.uma.labels.store.directory.name\": \"ds.localtest.me:1389\",
        \"org.forgerock.services.uma.labels.store.loginid\": \"uid=admin\",
        \"org.forgerock.services.uma.labels.store.password\": \"password\",
        \"org.forgerock.services.uma.labels.store.heartbeat\": \"10\"
      }
    }"
  )
  if [[ ${httpCode} -ne 200 ]]; then
    echo -e "\e[31m--Failed to set external UMA stores.\e[0m"
    echo "-- HTTP Code returend: ${httpCode}"
    exit 1
  fi
  echo "-- Done"
  echo " "

  echo "-> Setup Global Services OAuth2 Provider"
  httpCode=$(curl -sk -o /dev/null -w "%{http_code}" \
    "${serverURL}/json/global-config/services/oauth-oidc" \
    -X PUT -b "${path_amCookieFile}" \
    -H "Accept-API-Version: protocol=1.0,resource=1.0" \
    -H "Content-Type: application/json" \
    --data-binary "{
      \"defaults\": {
        \"coreOAuth2Config\": {
          \"accessTokenModificationScript\": \"[Empty]\",
          \"accessTokenMayActScript\": \"[Empty]\",
          \"oidcMayActScript\": \"[Empty]\"
        },
        \"coreOIDCConfig\": {
          \"oidcClaimsScript\": \"[Empty]\"
        },
        \"pluginsConfig\": {
          \"evaluateScopeScript\": \"[Empty]\",
          \"validateScopeScript\": \"[Empty]\",
          \"authorizeEndpointDataProviderScript\": \"[Empty]\"
        }
      }
    }"
  )
  if [[ ${httpCode} -ne 200 ]]; then
    echo -e "\e[31m--Failed to remove OAuth2 Provider default scripts.\e[0m"
    echo "-- HTTP Code returend: ${httpCode}"
    exit 1
  fi
  echo "-- Done"
  echo " "
}

# ----------------------------------------------------------------------------------
# NOTE: The below function template was taken from ForgeRock ForgeOps repo
#       https://github.com/ForgeRock/forgeops
# Parameters:
#  - ${1}: AM serverURL
#  - "{2}: Cookie file path"
# ----------------------------------------------------------------------------------
configure-server-site() {
  local httpCode="000"
  local serverURL="${1}"
  local path_amCookieFile="${2}"
  echo "-> Adding Server to Site"
  httpCode=$(curl -s -o /dev/null -w "%{http_code}" \
    "${serverURL}/json/global-config/servers/01/properties/general" \
    -X PUT -b "${path_amCookieFile}" \
    -H "Accept-API-Version: protocol=1.0,resource=1.0" \
    -H "Content-Type: application/json" \
    --data-binary "{
      \"amconfig.header.site\": {
        \"singleChoiceSite\": \"mainsite\"
      }
    }")
  if [[ $httpCode -ne 200 ]]; then
    echo -e "\e[31mFailed to set server site.\e[0m"
    echo "-- HTTP Code returend: ${httpCode}"
    exit 1
  fi
  echo "-- Done"
  echo " "
}