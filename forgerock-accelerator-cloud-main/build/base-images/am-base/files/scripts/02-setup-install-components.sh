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
echo "[ START: Running as User '$(id -anu)' ]"
echo " "

source "${MIDSHIPS_SCRIPTS}/tomcat-shared-functions.sh"
source "${path_tmp}/scripts/setup-functions.sh"

echo "-> Setting key variable(s)";
errorFound="false"
filename_cryptoTool="crypto-tool.jar"
filename_configUpgrader="config-upgrader.zip"
filename_configuratorTools="configurator-tools.zip"
path_amCookieFile="${path_tmp}/cookie.txt"
path_amExplodeDir="${path_tmp}/openam"
path_amsterBin="${AMSTER_HOME}/amster"
path_configuratorsdir="${AM_PATH_TOOLS}/configurators"
amServerPort="8080"
amServerUrl="http://localhost:${amServerPort}/${AM_URI}"
newServername="amserver"
path_placeholderTmpFile=
echo "-- Done";
echo " ";

echo "-> Displaying key variable(s)";
echo "   AM Version: '${VERSION_AM}'"
echo "   Amster Version: '${VERSION}'"
echo "   Download Path (AM): '${downloadPath_am}'"
echo "   Download Path (Amster): '${downloadPath_amster}'"
echo "   Temp Path (Binary): '${path_tmpBin}'"
echo "   Temp Path: '${path_tmpB}'"
echo "-- Done";
echo " ";

echo "-> Creating required folders";
mkdir -p "${AMSTER_HOME}" "${path_configuratorsdir}";
echo "-- Done";
echo " ";

echo "-> Exploding '${filename_am}' to '${path_tmp}'";
if [ ! -d "${path_tmp}" ]; then
  echo "-- ERROR: '${path_tmp}' does not exists. Required temp folder for image setup. Exiting ..."
  errorFound="true"
fi
if [ ! -d "${path_tmpBin}" ]; then
  echo "-- ERROR: '${path_tmpBin}' does not exists. It is the required desitination for AM tools. Exiting ..."
  errorFound="true"
fi
path_tmp01="${path_tmpBin}/${filename_am}"
if [ -f "${path_tmp01}" ]; then
  echo "-- Unzipping ..."
  unzip -q "${path_tmp01}" -d "${path_tmp}";
  echo "-- Removing ..."
  rm "${path_tmp01}"
else
  echo "-- ERROR: '${path_tmpBin}' does not exists. It is the required desitination for AM tools. Exiting ..."
  errorFound="true"
fi
echo "-- Done"
echo " "

if [ "${errorFound}" == "false" ]; then
  echo "Moving required files from exploded am.zip"
  echo "From: '${path_amExplodeDir}'"
  echo "To:'${path_tmpBin}'"
  echo "------------------------------------------"
  if [ ! -d "${path_amExplodeDir}" ]; then
    echo "-- ERROR: '${path_amExplodeDir}' does not exists. Check explode location of '${filename_am}' above. Exiting ..."
    errorFound="true"
  else
    echo "-> Copying required tools from exploded 'am.zip'"
    echo "   From: '${path_amExplodeDir}'"
    echo "   To (temp folder): '${path_tmpBin}'";
    echo " "
    echo "-- Listing source folder '${path_amExplodeDir}'"
    ls -ltra ${path_amExplodeDir}
    echo " "
    
    path_tmp01="${path_amExplodeDir}/AM-7.*.war"
    if [ -f ${path_tmp01} ]; then
      echo "-- Moving '$(basename ${path_tmp01})' ..."
      mv ${path_tmp01} ${path_tmpBin}/${AM_URI}.war
    else
      showMessage "'${path_tmp01}' NOT found." "error"
      errorFound="true"
    fi
    path_tmp01="${path_amExplodeDir}/Config-Upgrader-*.zip"
    if [ -f ${path_tmp01} ]; then
      echo "-- Moving '$(basename ${path_tmp01})' ..."
      mv ${path_tmp01} ${path_tmpBin}/${filename_configUpgrader}
    else
      showMessage "'${path_tmp01}' NOT found." "error"
      errorFound="true"
    fi
    path_tmp01="${path_amExplodeDir}/AM-crypto-tool-*.jar"
    if [ -f ${path_tmp01} ]; then
      echo "-- Moving '$(basename ${path_tmp01})' ..."
      mv ${path_tmp01} ${path_tmpBin}/${filename_cryptoTool}
    else
      showMessage "'${path_tmp01}' NOT found. Skipping ..." "warn"
    fi
    path_tmp01="${path_amExplodeDir}/AM-SSOConfiguratorTools-*.zip"
    if [ -f ${path_tmp01} ]; then
      echo "-- Moving '$(basename ${path_tmp01})' ..."
      mv ${path_tmp01} ${path_tmpBin}/${filename_configuratorTools}
    else
      showMessage "'${path_tmp01}' NOT found." "error"
      errorFound="true"
    fi

    echo " "
    echo "-- Listing destination folder '${path_tmpBin}'"
    ls -ltra ${path_tmpBin}
    echo "-- Done";
    echo " ";
  fi
fi

if [ "${errorFound}" == "false" ]; then
  echo "Deploying from temp folder:"
  echo "Folder: '${path_tmpBin}'"
  echo "---------------------------"
  echo " "

  echo "-> Deploying Amster";
  path_tmp01="${path_tmpBin}/${filename_amster}"
  if [ -f "${path_tmp01}" ] && [ -d "${AMSTER_HOME}" ]; then
    unzip -q ${path_tmp01} -d ${AMSTER_HOME};
    path_tmp01="${AMSTER_HOME}/amster"
    if [ -d "${path_tmp01}" ]; then
      echo "-- Sub folder '${path_tmp01}' found. Correcting to '${AMSTER_HOME}'"
      mv ${path_tmp01} ${path_tmp01}_tmp
      cd ${path_tmp01}_tmp
      mv * ${AMSTER_HOME}
    fi
    echo "-- Done";
    echo " ";
  else
    echo "-- ERROR: Either Amster file '${path_tmp01}' or folder '${AMSTER_HOME}' cannot be found."
    errorFound="true"
  fi

  echo "-> Deploying Crypto Tool";
  path_tmp01="${path_tmpBin}/${filename_cryptoTool}"
  if [ -f "${path_tmp01}" ] && [ -d "${AM_PATH_TOOLS}" ]; then
    cp ${path_tmp01} -d ${AM_PATH_TOOLS};
    echo "-- Done";
    echo " ";
  else
    echo "-- ERROR: Either file '${path_tmp01}' or folder '${AM_PATH_TOOLS}' cannot be found."
    errorFound="true"
  fi

  echo "-> Deploying Config Upgrader";
  path_tmp01="${path_tmpBin}/${filename_configUpgrader}"
  if [ -f "${path_tmp01}" ] && [ -d "${AM_PATH_TOOLS}" ]; then
    unzip -q ${path_tmp01} -d ${AM_PATH_TOOLS};
    echo "-- Done";
    echo " ";
  else
    echo "-- ERROR: Either file '${path_tmp01}' or folder '${AM_PATH_TOOLS}' cannot be found."
    errorFound="true"
  fi

  echo "-> Deploying Configurator Tool";
  path_tmp01="${path_tmpBin}/${filename_configuratorTools}"
  if [ -f "${path_tmp01}" ] && [ -d "${AM_PATH_TOOLS}" ]; then
    unzip -q ${path_tmp01} -d ${path_configuratorsdir};
    echo "-- Creating sample installation configuration ..."
    path_tmp01="${path_configuratorsdir}/sampleconfiguration"
    if [ -f "${path_tmp01}" ]; then
      cp ${path_tmp01} ${path_configuratorsdir}/config.properties
    else
      showMessage "'${path_tmp01}' NOT found. Skipping ..." "error"
      errorFound="true"
    fi
    echo "-- Done";
    echo " ";
  else
    showMessage "Either file '${path_tmp01}' or folder '${AM_PATH_TOOLS}' cannot be found." "error"
    errorFound="true"
  fi

  echo "-> Deploying additional files";
  if [ -d "${AM_PATH_TOOLS}" ]; then
    path_tmp01="${path_tmp}/openam/samples/docker/images/am-base/scripts/serverconfig-modification.groovy"
    strTmp="'${path_tmp01}' for AM v7.3- does NOT exists."
    [ ! -f "${path_tmp01}" ] && path_tmp01="${path_tmp}/scripts/serverconfig-modification.groovy" && strTmp="'${path_tmp01}' for AM v7.4+ does NOT exists."
    if [ -f "${path_tmp01}" ]; then
      cp "${path_tmp01}" "${AM_PATH_TOOLS}/"
    else
      showMessage "${strTmp}'" "error"
      errorFound="true"
    fi
    cp "${path_tmp}/openam/samples/docker/images/am-base/serverconfig.xml" "${AM_PATH_TOOLS}/"
    cp "${path_tmp}/openam/samples/docker/images/am-base/boot.json" "${AM_PATH_TOOLS}/"
    cp ${path_tmpBin}/${filename_cryptoTool} ${AM_PATH_TOOLS}
    echo "-- Done";
    echo " ";
  else
    echo "-- ERROR: \failure deploying additional file(s) to '${AM_PATH_TOOLS}'. See above logs."
    errorFound="true"
  fi

  echo "-> Deploying Access Manager (AM) on Tomcat";
  path_tmp01="${path_tmpBin}/${AM_URI}.war"
  if [ -f "${path_tmp01}" ] && [ -d "${CATALINA_HOME}/webapps" ]; then
    path_amWar="${CATALINA_HOME}/webapps/${AM_URI}.war"
    mv ${path_tmp01} "${path_amWar}";
    unzip -q "${path_amWar}" -d "${CATALINA_HOME}/webapps/${AM_URI}";
    rm "${path_amWar}"
    echo "-- Done";
    echo " ";
  else
    echo "-- ERROR: Either AM file '${path_tmp01}' or folder '${CATALINA_HOME}/webapps) cannot be found."
    errorFound="true"
  fi
  
  if [ "$(ls -A ${AM_HOME} | grep -i \\.jar\$)" ]; then
    path_amPlugins="${CATALINA_HOME}/webapps/${AM_URI}/WEB-INF/lib/"
    echo "-> Deploying AM plugins"
    echo "-- Copying to ${path_amPlugins}"
    mv -f ${AM_HOME}/*.jar ${path_amPlugins}
    echo "-- Done"
    echo " "
  fi
fi

if [ "${errorFound}" == "false" ]; then
  export CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.identity.sm.filebased_embedded_enabled=true"

  echo "Setting up Base Access Manager (AM)"
  echo "-----------------------------------"
  echo " "
  manageTomcat "start-debug" "${amServerUrl}"

  echo "-> Updating default configuration properties"
  path_tmp01="${path_configuratorsdir}/config.properties"
  replaceVarValInfile "${path_tmp01}" "SERVER_URL=" "http://localhost:${amServerPort}"
  replaceVarValInfile "${path_tmp01}" "DEPLOYMENT_URI=" "/am"
  replaceVarValInfile "${path_tmp01}" "BASE_DIR=" "/opt/am/"
  replaceVarValInfile "${path_tmp01}" "ADMIN_PWD=" "password"
  replaceVarValInfile "${path_tmp01}" "COOKIE_DOMAIN=" "example.com"
  replaceVarValInfile "${path_tmp01}" "DATA_STORE=" "embedded"
  replaceVarValInfile "${path_tmp01}" "DIRECTORY_SSL=" "SSL"
  replaceVarValInfile "${path_tmp01}" "DIRECTORY_SERVER=" "localhost"
  replaceVarValInfile "${path_tmp01}" "DS_DIRMGRDN=" "uid=admin"
  replaceVarValInfile "${path_tmp01}" "DS_DIRMGRPASSWD=" "password"
  replaceVarValInfile "${path_tmp01}" "DIRECTORY_PORT=" "50636"
  replaceVarValInfile "${path_tmp01}" "ACCEPT_LICENSES=" "true"
  replaceVarValInfile "${path_tmp01}" "ROOT_SUFFIX=" "ou=am-config"
  echo "-- Done";
  echo " ";

  echo "-> Displaying configuration to be used"
  grep -v "^#" ${path_tmp01} | grep -v "^$"
  echo "-- Done";
  echo " ";

  echo "[ AM Installation ]";
  echo ""
  java -jar ${path_configuratorsdir}/openam-configurator-tool-*.jar --file ${path_tmp01}
  echo "-- Done";
  echo " ";

  echo "-> Importing Site and Server information ...";
  path_tmp01="${path_tmp}/amster/configure-am.amster"
  if [ -f "${path_tmp01}" ] && [ -f "${path_amsterBin}" ]; then
    "${path_amsterBin}" "${path_tmp01}"
  else
    echo "-- ERROR: Either file '${path_tmp01}' or '${AMSTER_HOME} cannot be found. Exiting ..."
    errorFound="true"
  fi
  echo "-- Done";
  echo " ";

  echo "-> Authenticating ..."
  tokenId=$(curl -c "${path_amCookieFile}" -sk --request POST \
    --header "Accept-API-Version: resource=2.0, protocol=1.0" \
    --header "Content-Type: application/json" \
    --header "X-OpenAM-Username: amadmin" \
    --header "X-OpenAM-Password: password" \
    "${amServerUrl}/json/realms/root/authenticate" | jq .tokenId)
  echo "-- Token ID returned '${tokenId}'"
  if [ "${tokenId}" == "null" ] || [ -z "${tokenId}" ]; then
    echo "-- ERROR: Cannot authenticate with Access Manager. Exiting ..."
    errorFound="true"
  else
    echo "-- Authenticated with AM sucessfully"
  fi
  echo "-- Done";
  echo " ";

  if [ "${errorFound}" == "false" ]; then
    configure-external-datastores "${amServerUrl}" "${path_amCookieFile}"
    configure-server-site "${amServerUrl}" "${path_amCookieFile}"
    manageTomcat "stop" "${amServerUrl}"
    echo " "

    echo "PLACEHOLDERS: Updating Dummy Installation files"
    echo "-----------------------------------------------"
    echo " "

    echo "-> Renaming primary server file"
    path_tmp01="${AM_HOME}/config/services/realm/root/iplanetamplatformservice/1.0/globalconfig/default/com-sun-identity-servers"
    path_soruce="${path_tmp01}/http___localhost_8080_am.json"
    path_destination="${path_tmp01}/http___${newServername}_8080_am.json"
    if [ -f "${path_soruce}" ]; then
      mv "${path_soruce}" "${path_destination}"
      if [ ! -f "${path_destination}" ]; then
        echo "-- ERROR: '${path_soruce}' NOT created."
        errorFound="true"
      fi
    else
      echo "-- ERROR: Source file '${path_soruce}' NOT found."
      errorFound="true"
    fi
    echo "-- Listing folder contents:"
    ls -ltra "${path_tmp01}"
    echo "-- Done"
    echo " "

    echo "-> Updating hostname in config files"
    oldHostname="localhost"
    newHostname="${newServername}"
    echo "   From: '${oldHostname}'"
    echo "   To: '${newHostname}'"
    find ${AM_PATH_CONFIG}/. -name '*.json' -type f -exec sed -i "s+$oldHostname+$newHostname+g" {} \;
    echo "   > Updated"
    echo "-- Done"
    echo " "

    echo "-> Updating 'boot.json'"
    path_soruce="${AM_PATH_TOOLS}/boot.json"
    path_destination="${AM_PATH_CONFIG}/boot.json"
    path_tmp01="${path_tmp}/boot.json"
    cp "${path_soruce}" "${path_destination}"
    # To boot without DS, need a separate boot keystore with 2 keys (dsameuser and cfgstorepwd). 
    # These keys should not exists in normal AM keystore
    cat "${path_soruce}" | \
      jq ".instance=\"http://${newServername}:${amServerPort}/am\" " | \
      jq ".keystores.default.keyStorePasswordFile=\"${AM_PATH_KEYSTORES}/boot/.storepass\" " | \
      jq ".keystores.default.keyPasswordFile=\"${AM_PATH_KEYSTORES}/boot/.keypass\" " | \
      jq ".keystores.default.keyStoreFile=\"${AM_PATH_KEYSTORES}/boot/keystore.jceks\" " \
      > "${path_tmp01}"
    cp "${path_tmp01}" "${path_destination}"
    echo "-- Done"
    echo " "

    echo "Overlay harden configuration"
    echo "----------------------------"
    echo " "
    echo "-> Applying additional hardened configuration";
    path_soruce="${path_tmp}/config-hardened/services/*"
    path_destination="${AM_PATH_CONFIG}/services/"
    cp -r ${path_soruce} ${path_destination}
    if [ $? -ne 0 ]; then
      echo "-- ERROR: Something went wrong copying from '${path_soruce}' to '${path_destination}'"
      echo "   Exiting ..."
      errorFound="true"
    fi
    echo "-- Done"
    echo " "

    # Amster RSA Key used by Midships FACT tool to export Application and Policy Configurations
    path_tmp01="${AM_PATH_SECURITY}/keys/amster/amster_rsa"
    path_tmp02="${AM_PATH_CONFIG}/amster"
    echo "-> Backing up Amster RSA key 'path_tmp01'"
    if [ -f "${path_tmp01}" ]; then
      if [ ! -d "${path_tmp02}" ]; then
        echo "-- Creating base folder '${path_tmp02}' ..."
        mkdir -p "${path_tmp02}"
      fi
      echo "-- Backup started ..."
      cp -p "${path_tmp01}" "${path_tmp02}/"
      chmod -R 700 "${path_tmp02}/"
    else
      echo "-- ERROR: Amster RSA File '${path_tmp01}' or CANNOT be found."
      errorFound="true"
    fi
    echo "-- Done"
    echo " "

    # NOTE: MUST be done to ensure successful startup of AM
    # 'var' folder will be re-created on AM start up
    # 'opends' folder not required, but AM fails if not deleted.
    echo "-> Removing 'opendjs', and 'var' folder";
    rm -rf "${AM_HOME}/opends" "${AM_HOME}/var"
    if [ -d "${AM_HOME}/opends" ] || [ -d "${AM_HOME}/var" ]; then
      echo "-- ERROR: Either one or more of the below folders were not deleted:"
      echo "   > '${AM_HOME}/opends'"
      echo "   > '${AM_HOME}/var'"
      errorFound="true"
    fi
    echo "-- Done"  
    echo " "

    echo "-> Updating Server Defaults"
    arr_files=($(find ${AM_PATH_CONFIG}/. -type f -name "server-default.json"))
    for file in "${arr_files[@]}"; do
      if [ -f "${file}" ]; then
        echo "   File: '${file}'"
        path_tmpFile="${file}.updated"
        cat "${file}" | jq . > "${path_tmpFile}"
        echo "-- Adding placehoder to default Cookie Name"
        strReplacePrefix="com.iplanet.am.cookie.name="
        strReplace="${strReplacePrefix}\&{am.cookie.name}"
        strFind="$(grep -o "${strReplacePrefix}.*\b" "${path_tmpFile}")"
        echo "   > Updating from '${strFind}'"
        echo "   > Updating to '${strReplace}'"
        sed -i "s+$strFind+$strReplace+g" "${file}"
        echo "-- Adding placehoder to Token Store Base DN"
        strReplacePrefix="org.forgerock.services.cts.store.root.suffix="
        strReplace="${strReplacePrefix}\&{am.basedn.ts}"
        strFind="$(grep -o "${strReplacePrefix}.*\b" "${path_tmpFile}")"
        echo "   > Updating from '${strFind}'"
        echo "   > Updating to '${strReplace}'"
        sed -i "s+$strFind+$strReplace+g" "${file}"
        echo "-- Done"
        echo "-- Cleaning up ..."
        rm "${path_tmpFile}"
      fi
    done
    echo "-- Done"  
    echo " "

    path_placeholderTmpFile="${AM_PATH_TOOLS}/amupgrade/rules/placeholders/7.0.0-placeholders.groovy"
    echo "-> Updating Placeholder template '${path_placeholderTmpFile}'"
    if [ -f "${path_placeholderTmpFile}" ]; then
      echo "-- Updating Server URL:"
      strFind="http://am:80/am"
      strReplace="http://${newServername}:${amServerPort}/am"
      echo "   From: '${strFind}'"
      echo "   To: '${strReplace}'"
      sed -i "s+$strFind+$strReplace+g" "${path_placeholderTmpFile}"
      echo "-- Update Server URL placeholder:"
      strFind="\&{am.server.protocol}://\&{am.server.fqdn}"
      strReplace="\&{am.server.protocol}://\&{am.server.fqdn}:\&{am.server.port}"
      echo "   From: '${strFind}'"
      echo "   To: '${strReplace}'"
      sed -i "s+$strFind+$strReplace+g" "${path_placeholderTmpFile}"
      echo "-- Update SECRETS_PATH variable:"
      strFind="\&{secrets.path}/amster"
      strReplace="\&{am.path.secrets.amster}"
      echo "   From: '${strFind}'"
      echo "   To: '${strReplace}'"
      sed -i "s+$strFind+$strReplace+g" "${path_placeholderTmpFile}"
    else
      echo "File '${path_placeholderTmpFile}' or CANNOT be found."
      errorFound="true"
    fi
    echo "-- Done"
    echo " "

    path_placeholderTmpFile="${AM_PATH_TOOLS}/serverconfig-modification.groovy"
    echo "-> Updating Placeholder template '${path_placeholderTmpFile}'"
    if [ -f "${path_placeholderTmpFile}" ]; then
      echo "-- Updating Server URL:"
      strFind="http://am:"
      strReplace="http://${newServername}:"
      echo "   From: '${strFind}'"
      echo "   To: '${strReplace}'"
      sed -i "s+$strFind+$strReplace+g" "${path_placeholderTmpFile}"
      echo "-- Update Server Port:"
      strFind="80"
      strReplace="${amServerPort}"
      echo "   From: '${strFind}'"
      echo "   To: '${strReplace}'"
      sed -i "s+$strFind+$strReplace+g" "${path_placeholderTmpFile}"
      echo "-- Update Server Host:"
      strFind="\"am\""
      strReplace="\"${newServername}\""
      echo "   From: '${strFind}'"
      echo "   To: '${strReplace}'"
      sed -i "s+$strFind+$strReplace+g" "${path_placeholderTmpFile}"
      echo "-- Update Server fqdnMap:"
      strFind="\[am\]=am"
      strReplace="\[${newServername}\]=${newServername}"
      echo "   From: '${strFind}'"
      echo "   To: '${strReplace}'"
      sed -i "s+$strFind+$strReplace+g" "${path_placeholderTmpFile}"
    else
      echo "File '${path_placeholderTmpFile}' or CANNOT be found."
      errorFound="true"
    fi
    echo "-- Done"
    echo " "
  fi
fi

if [ "${errorFound}" == "true" ]; then
  echo "-- ERROR:  Kindly see above log for details on erros. Exiting ..."
  exit 1
fi

echo "-> Removing Tomcat logs";
rm ${CATALINA_HOME}/logs/catalina.out;
echo "-- Done";
echo " ";

echo "-> Cleaning up";
rm -rf ${path_tmp};
echo "-- Done";
echo " ";

echo "[ END: Running as User '$(id -anu)' ]"
exit 0
