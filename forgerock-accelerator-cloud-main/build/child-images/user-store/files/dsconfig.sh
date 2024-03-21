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

# echo "Update 'Default Password Policy' scheme to 'PBKDF2-HMAC-SHA256'"
# ${DS_APP}/bin/dsconfig set-password-policy-prop \
# --policy-name "Default Password Policy" \
# --set default-password-storage-scheme:PBKDF2-HMAC-SHA256 \
# --hostname "${svcURL_curr}" --port ${adminConnectorPort} \
# --bindDN "${rootUserDN}" --bindPassword "${rootUserPassword}" \
# --trustAll  --no-prompt
# echo "-- Done"
# echo ""
# echo "-> Configuring index for custom attributes"
# backendName="userStore"
# ${DS_APP}/bin/dsconfig  create-backend-index  --hostname "${svcURL_curr}" --port ${adminConnectorPort}  --bindDN "${rootUserDN}"  --bindPassword "${rootUserPassword}" --backend-name ${backendName} --index-name cif  --set index-type:equality  --trustAll  --no-prompt
# ${DS_APP}/bin/dsconfig  create-backend-index  --hostname "${svcURL_curr}" --port ${adminConnectorPort}  --bindDN "${rootUserDN}"  --bindPassword "${rootUserPassword}" --backend-name ${backendName} --index-name customerId  --set index-type:equality  --trustAll  --no-prompt
# ${DS_APP}/bin/dsconfig  create-backend-index  --hostname "${svcURL_curr}" --port ${adminConnectorPort}  --bindDN "${rootUserDN}"  --bindPassword "${rootUserPassword}" --backend-name ${backendName} --index-name ktp  --set index-type:equality  --trustAll  --no-prompt
# echo "-- Done"
# echo ""

# echo "-> Configuring Plugin properties"
# ${DS_APP}/bin/dsconfig  set-plugin-prop  --hostname "${svcURL_curr}"  --port ${adminConnectorPort}  --bindDN "${rootUserDN}" --bindPassword "${rootUserPassword}"  --plugin-name "UID Unique Attribute"  --add type:mail  --trustAll --set enabled:true --no-prompt
# ${DS_APP}/bin/dsconfig  set-plugin-prop  --hostname "${svcURL_curr}"  --port ${adminConnectorPort}  --bindDN "${rootUserDN}" --bindPassword "${rootUserPassword}"  --plugin-name "UID Unique Attribute"  --add type:cif  --trustAll --set enabled:true --no-prompt
# ${DS_APP}/bin/dsconfig  set-plugin-prop  --hostname "${svcURL_curr}"  --port ${adminConnectorPort}  --bindDN "${rootUserDN}" --bindPassword "${rootUserPassword}"  --plugin-name "UID Unique Attribute"  --add type:customerId  --trustAll --set enabled:true --no-prompt
# ${DS_APP}/bin/dsconfig  set-plugin-prop  --hostname "${svcURL_curr}"  --port ${adminConnectorPort}  --bindDN "${rootUserDN}" --bindPassword "${rootUserPassword}"  --plugin-name "UID Unique Attribute"  --add type:telephoneNumber --trustAll --set enabled:true --no-prompt
# ${DS_APP}/bin/dsconfig  set-plugin-prop  --hostname "${svcURL_curr}"  --port ${adminConnectorPort}  --bindDN "${rootUserDN}" --bindPassword "${rootUserPassword}"  --plugin-name "UID Unique Attribute"  --add type:ktp --trustAll --set enabled:true --no-prompt
# echo "-- Done"
# echo ""

# echo "-> Creating Password Validators"
# echo ""
# tmpStr1="9 Characters"
# echo "-- Creating validator (${tmpStr1})"
# ${DS_APP}/bin/dsconfig create-password-validator --hostname "${svcURL_curr}" --port ${adminConnectorPort} \
#  --bindDN "${rootUserDN}" --bindPassword "${rootUserPassword}" --validator-name "${tmpStr1}" --type length-based \
#  --set enabled:true --set min-password-length:9 --trustAll --no-prompt
# echo "-- Done"
# echo ""
# tmpStr2="Weak Passwords"
# echo "-- Creating validator (${tmpStr2})"
# ${DS_APP}/bin/dsconfig create-password-validator --hostname "${svcURL_curr}" --port ${adminConnectorPort} \
#   --bindDN "${rootUserDN}" --bindPassword "${rootUserPassword}" --validator-name "${tmpStr2}" --type dictionary \
#   --set enabled:true --set dictionary-file:config/common-passwords.txt --set case-sensitive-validation:true \
#   --set test-reversed-password:false --trustAll --no-prompt
# echo "-- Done"
# echo ""
# tmpStr3="Valid Passwords Characters"
# echo "-- Creating validator (${tmpStr3})"
# ${DS_APP}/bin/dsconfig create-password-validator --hostname "${svcURL_curr}" --port ${adminConnectorPort} \
#   --bindDN "${rootUserDN}" --bindPassword "${rootUserPassword}" --validator-name "${tmpStr3}" --type character-set \
#   --set allow-unclassified-characters:true --set enabled:true \
#   --set character-set:0:abcdefghijklmnopqrstuvwxyz \
#   --set character-set:0:ABCDEFGHIJKLMNOPQRSTUVWXYZ \
#   --set character-set:0:0123456789 \
#   --set character-set:0:\!\"\#\$%\&\'\(\)\*+\,-./:\;\\\<=\>\?@\[\]\^_\`\{\|\}~ \
#   --set min-character-sets:3 \
#  --trustAll --no-prompt
# echo ""

# echo "-> Updating default password policy to:"
# echo "   : password-history-count is 3"
# echo "   : minimum-password-length is 9"
# echo "   : lowercase characters (a through z)"
# echo "   : uppercase characters (A through Z)"
# echo "   : Base 10 digits (0 through 9)"
# echo "   : Non-alphabetic characters (for example, !, \$, #, %)"
# ${DS_APP}/bin/dsconfig set-password-policy-prop --hostname "${svcURL_curr}" --port ${adminConnectorPort} \
#   --bindDN "${rootUserDN}" --bindPassword "${rootUserPassword}" --policy-name "Default Password Policy" \
#   --set password-history-count:3 \
#   --set password-validator:"${tmpStr1}" \
#   --set password-validator:"${tmpStr2}" \
#   --set password-validator:"${tmpStr3}" \
#   --trustAll \
#   --no-prompt
# echo "-- Done"
# echo ""

# echo "-> Doing the below LDAP update:"
# echo "  - Creating 'ou=mobileDevices,ou=identities'"
# echo "  - Adding object class 'kbMobileDevice' to 'ou=mobileDevices'"
# echo "  - Adding object class 'kbUserExtension' to 'ou=people,ou=identities'"
# ${DS_APP}/bin/ldapmodify --hostname "${svcURL_curr}" --bindDN "${rootUserDN}" \
#   --bindPassword "${rootUserPassword}" --port ${ldapsPort} --useSsl --TrustAll <<EOF
# # Creating mobileDevices ou
# dn: ou=mobileDevices,ou=identities
# changetype: add
# objectclass: top
# objectclass: organizationalUnit
# ou: mobileDevices
# description: Custom OU for Mobile Devices

# # Adding object class kbMobileDevice to ou=mobileDevices
# dn: ou=mobileDevices,ou=identities
# changetype: modify
# add: objectClass
# objectClass: kbMobileDevice

# # Adding object class kbUserExtension to ou=people,ou=identities
# dn: ou=people,ou=identities
# changetype: modify
# add: objectClass
# objectClass: kbUserExtension
# EOF

# echo "-> Adding object class 'Customer' to 'ou=people,ou=identities'"
# ${DS_APP}/bin/ldapmodify --hostname "${svcURL_curr}" --bindDN "${rootUserDN}" \
#   --bindPassword "${rootUserPassword}" --port ${ldapsPort} --useSsl --TrustAll <<EOF
# # Adding object class Customer to ou=people,ou=identities
# dn: ou=people,ou=identities
# changetype: modify
# add: objectClass
# objectClass: Customer
# EOF
# echo ""

# echo "-> Adding 2 Users Using 'Customer' object class attributes"
# ${DS_APP}/bin/ldapmodify --hostname "${svcURL_curr}" --bindDN "${rootUserDN}" \
#   --bindPassword "${rootUserPassword}" --port ${ldapsPort} --useSsl --TrustAll <<EOF
# # Adding object class Customer to ou=people,ou=identities
# dn: uid=fruser1,ou=people,ou=identities
# objectClass: person
# objectClass: top
# objectClass: inetuser
# objectClass: Customer
# objectClass: inetorgperson
# mail: fruser1@sample.com
# uid: fruser1
# cn: fruser1
# sn: fruser1-sn
# userPassword: OnePiece!stheB3st
# status: alive
# authStatus: roaming

# dn: uid=fruser2,ou=people,ou=identities
# objectClass: person
# objectClass: top
# objectClass: inetuser
# objectClass: Customer
# objectClass: inetorgperson
# mail: fruser2@sample.com
# uid: fruser2
# cn: fruser2
# sn: fruser2-sn
# userPassword: OnePiece!stheB3st
# status: missing
# authStatus: static
# EOF
# echo ""