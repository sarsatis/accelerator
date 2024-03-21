#!/usr/bin/env bash
# =====================================================================
# MIDSHIPS
# COPYRIGHT 2023
# This file contains scripts to be executed after creation of MIDSHIPS
# SECRETS MANAGEMENT Kubernetes solution required by Midships Ready To
# Integrate (RTI) solution.
#
# NOTE: Don't check this file into source control with
#       any sensitive hard coded vaules.
#
# Legal Notice: Installation and use of this script is subject to
# a license agreement with Midships Limited (a company registered
# in England, under company registration number: 11324587).
# This script cannot be modified or shared with another organisation
# unless approved in writing by Midships Limited.
# You as a user of this script must review, accept and comply with the
# license terms of each downloaded/installed package that is referenced
# by this script. By proceeding with the installation, you are accepting
# the license terms of each package, and acknowledging that your use of
# each package will be subject to its respective license terms.
# =====================================================================
set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace # May leak secrets so only enable for debugging

function usage() {
  cat <<EOF >&2
usage: generate-certs.sh  [OPTIONS]

Generates self-signed certificates for use in the Forgerock application for Mutual TLS connections between components.
Certificates will dumped into a sub-directory of the script location called 'generated-certs/' with a sub-directory
for each component, am-cert, us-cert etc.

For every component, a certificate file, a key file and a certificate details file will be generated.

The certificate can be loaded into the trust store of an application that needs to trust that application and the
application itself.

The key file should only be loaded into the component it was created for - it is secret to that application.

The certificate details file is used to create the Certificate Signing Request and is retained for information only.

Certificate Common Names have a hard limit of 64 characters, so if we are generating certificates for branches that
have very long DNS entries, the certificate request will be modified so that the namespace name provided will be used
as a Common Name, and the long DNS entry will be added as a Subject Alternative Name.  Therefore the namespace name is
required to support this logic.

OPTIONS
  -ns1 "namespace-name", --namespace-name-1 "namespace-name"
      The namespace name for the first cluster use in the Common Name if the FQDN of access manager is more than 64 bytes.  Will
      be used automatically in this case.
      Required

  -ns2 "namespace-name", --namespace-name-2 "namespace-name"
      The namespace name for the second cluster use in the Common Name if the FQDN of access manager is more than 64 bytes.  Will
      be used automatically in this case.
      Required

  -amfqdn1 "access-manager-fully-qualified-domain-name", --access-manager-fqdn-1 "access-manager-fully-qualified-domain-name"
      The fully qualified domain name of the first cluster access manager component -
        e.g. am1.client.name.com
      Required

  -amfqdn2 "access-manager-fully-qualified-domain-name", --access-manager-fqdn-2 "access-manager-fully-qualified-domain-name"
      The fully qualified domain name of the first cluster access manager component -
        e.g. am2.client.name.com
      Required

  -idmfqdn1 "idm-fully-qualified-domain-name", --idm-fqdn-1 "idm-fully-qualified-domain-name"
      The fully qualified domain name of the first cluster idm component -
        e.g. idm1.client.name.com
      Required

  -idmfqdn2 "idm-fully-qualified-domain-name", --idm-fqdn-2 "idm-fully-qualified-domain-name"
      The fully qualified domain name of the first cluster idm component -
        e.g. idm2.client.name.com
      Required

  -svcAM "service-name-access-manager"
      The service name of the access manager component -
        e.g. forgerock-access-manager
      Required

  -svcCS "service-name-app-policy-store"
      The service name of the application policy store component -
        e.g. forgerock-app-policy-store
      Required

  -svcCS "service-name-user-store"
      The service name of the application policy store component -
        e.g. forgerock-app-policy-store
      Required

  -svcCS "service-name-token-store"
      The service name of the application policy store component -
        e.g. forgerock-app-policy-store
      Required

  -svcCS "service-name-relication-server"
      The service name of the application policy store component -
        e.g. forgerock-app-policy-store
      Required

  -svcIG "service-name-identity-gateway"
      The service name of the identity gateway component -
        e.g. forgerock-identity-gateway
      Required

  -svcIDM "service-name-identity-manager"
      The service name of the identity manager component -
        e.g. forgerock-identity-manager
      Required

EOF
[[ -n "$*" ]] && echo "ERROR: $*" >&2
exit 1
}

fqdn_AM_1=
fqdn_AM_2=
fqdn_1=
fqdn_2=
namespace_name_1=
namespace_name_2=
svc_AM="forgerock-access-manager"
svc_US="forgerock-user-store"
svc_TS="forgerock-token-store"
svc_CS="forgerock-app-policy-store"
svc_RS="forgerock-repl-server"
svc_IG="forgerock-ig"
svc_IDM="forgerock-idm"
script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
certsLocation="${script_dir}/generated-certs"

while [[ $# -gt 0 ]]
  do
    case "$1" in
      ( -h | --help )
        usage
        ;;
      ( -amfqdn1 | --access-manager-fqdn-1 )
        fqdn_AM_1="$2"
        shift 2
        ;;
      ( -amfqdn2 | --access-manager-fqdn-2 )
        fqdn_AM_2="$2"
        shift 2
        ;;
      ( -idmfqdn1 | --idm-fqdn-1 )
        fqdn_1="$2"
        shift 2
        ;;
      ( -idmfqdn2 | --idm-fqdn-2 )
        fqdn_2="$2"
        shift 2
        ;;
      ( -ns1 | --namespace-name-1 )
        namespace_name_1="$2"
        shift 2
        ;;
      ( -ns2 | --namespace-name-2 )
        namespace_name_2="$2"
        shift 2
        ;;
      ( -svcAM | --service-access-manager )
        svc_AM="$2"
        shift 2
        ;;
      ( -svcUS | --service-user-store )
        svc_US="$2"
        shift 2
        ;;
      ( -svcTS | --service-token-store )
        svc_TS="$2"
        shift 2
        ;;
      ( -svcCS | --service-app-policy-store )
        svc_CS="$2"
        shift 2
        ;;
      ( -svcRS | --service-replication-server )
        svc_RS="$2"
        shift 2
        ;;
      ( -svcIDM | --service-identity-manager )
        svc_IDM="$2"
        shift 2
        ;;
      ( -svcIG | --service-identity-gateway )
        svc_IG="$2"
        shift 2
        ;;
      *)
        usage "Unknown option passed in"
        ;;
    esac
  done

if [ -z "${fqdn_AM_1}" ]; then
  usage "Required option '-amfqdn1 | --access-manager-fqdn-1' is Empty"
fi
if [ -z "${fqdn_AM_2}" ]; then
  usage "Required option '-amfqdn2 | --access-manager-fqdn-2' is Empty"
fi

if [ -z "${fqdn_1}" ]; then
  usage "Required option '-idmfqdn1 | --idm-fqdn-1' is Empty"
fi
if [ -z "${fqdn_2}" ]; then
  usage "Required option '-idmfqdn2 | --idm-fqdn-2' is Empty"
fi

if [ -z "${namespace_name_1}" ]; then
  usage "Required option '-ns1 | --namespace-name-1' is Empty"
fi
if [ -z "${namespace_name_2}" ]; then
  usage "Required option '-ns2 | --namespace-name-2' is Empty"
fi
if [ -d "${certsLocation}" ]; then
  echo "-- Removing existing folder '${certsLocation}'"
  rm -rf "${certsLocation}" 
  echo "-- Done"
  echo 
fi

createSelfSignedCert () {
  echo "> Entered createSelfSignedCert ()"
  echo ""
  if [ -z "${1+x}" ]; then
    echo "-- {1} is Empty. This should be Certificate Name"
    "${1}"="certName"
    echo "-- {1} Set to ${1}"
    echo ""
  fi

  if [ -z "${2+x}" ]; then
    echo "-- {2} is Empty. This should be Certificate save folder location"
    "${2}"="generated-certs/"
    echo "-- {2} Set to ${2}"
    echo ""
  fi

  if [ -z "${3+x}" ]; then
    echo "-- {3} is Empty. This should be FQDN to be used as Certificate CN (Common Name)"
    echo "-- Exiting ..."
    echo ""
    exit
  fi

  if [ -z "${4+x}" ]; then
    echo "-- {3} is Empty. This should be FQDN to be used as SAN (Subject Alternative Names)"
    echo "-- Exiting ..."
    echo ""
    exit
  fi

  if [ -z "${5+x}" ];then
    echo "-- {5} is Empty. This should be additional FQDN to be used as SAN (Subject Alternative Names)"
    fqdnSAN2="localhost"
    echo "-- {5} Set to ${fqdnSAN2}"
    echo ""
  else
    fqdnSAN2=${5}
  fi

  if [ -z ${6+x} ]; then
    echo "-- {6} is Empty. This should be additional FQDN to be used as SAN (Subject Alternative Names)"
    fqdnSAN3="ignore"
    echo "-- {6} Set to ${fqdnSAN3}"
    echo ""
  else
    fqdnSAN3=${6}
  fi
  if [ -z ${7+x} ]; then
    echo "-- {7} is Empty. This should be additional FQDN to be used as SAN (Subject Alternative Names)"
    fqdnSAN4="ignore"
    echo "-- {7} Set to ${fqdnSAN4}"
    echo ""
  else
    fqdnSAN4=${7}
  fi
  if [ -z ${8+x} ]; then
    echo "-- {8} is Empty. This should be additional FQDN to be used as SAN (Subject Alternative Names)"
    fqdnSAN5="ignore"
    echo "-- {8} Set to ${fqdnSAN5}"
    echo ""
  else
    fqdnSAN5=${8}
  fi
  if [ -z ${9+x} ]; then
    echo "-- {9} is Empty. This should be additional FQDN to be used as SAN (Subject Alternative Names)"
    fqdnSAN6="ignore"
    echo "-- {9} Set to ${fqdnSAN6}"
    echo ""
  else
    fqdnSAN6=${9}
  fi
  if [ -z ${10+x} ]; then
    echo "-- {10} is Empty. This should be additional FQDN to be used as SAN (Subject Alternative Names)"
    fqdnSAN7="ignore"
    echo "-- {10} Set to ${fqdnSAN7}"
    echo ""
  else
    fqdnSAN7=${8}
  fi

  certName=${1}
  certCN=${3}
  fqdnSAN=${4}

  certSaveFolder="${2}"

  if [ -f "${certSaveFolder}/certdetails.txt" ]; then
    echo "-- Deleting existing file '${certSaveFolder}/certdetails.txt'"
    rm "${certSaveFolder}/certdetails.txt"
    echo "-- Done"
    echo ""
  fi

  echo "-- Creating certificate"
  mkdir -p "${certSaveFolder}"

# Creating self signed cert details file
cat << EOF >> "${certSaveFolder}/certdetails.txt"
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = UK
ST = London
L = London
O = Midships
OU = Midships
emailAddress = admin@Midships.io
CN = ${certCN}

[req_ext]
subjectAltName = @otherCNs

[otherCNs]
DNS.1 = ${fqdnSAN}
DNS.2 = *.${fqdnSAN}
DNS.3 = ${fqdnSAN2}
DNS.4 = *.${fqdnSAN2}
DNS.5 = ${certCN}
DNS.6 = *.${certCN}
DNS.7 = *.${certCN#*.}
DNS.8 = localhost
EOF

cat << EOF >> "${certSaveFolder}/certdetails_type2.txt"
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = UK
ST = London
L = London
O = Midships
OU = Midships
emailAddress = admin@Midships.io
CN = ${certCN}

[req_ext]
subjectAltName = @otherCNs

[otherCNs]
DNS.1 = ${fqdnSAN}
DNS.2 = *.${fqdnSAN#*.}
DNS.8 = *.${fqdnSAN}
DNS.3 = ${fqdnSAN2}
DNS.4 = *.${fqdnSAN2}
DNS.5 = ${fqdnSAN3}
DNS.6 = *.${fqdnSAN3}
DNS.7 = ${certCN}
DNS.8 = *.${certCN}
DNS.9 = *.${certCN#*.}
DNS.10 = localhost
EOF

cat << EOF >> "${certSaveFolder}/certdetails_type3.txt"
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = UK
ST = London
L = London
O = Midships
OU = Midships
emailAddress = admin@Midships.io
CN = ${certCN}

[req_ext]
subjectAltName = @otherCNs

[otherCNs]
DNS.1 = ${fqdnSAN}
DNS.2 = *.${fqdnSAN#*.}
DNS.8 = *.${fqdnSAN}
DNS.3 = ${fqdnSAN2}
DNS.4 = *.${fqdnSAN2}
DNS.5 = ${fqdnSAN3}
DNS.6 = *.${fqdnSAN3}
DNS.7 = ${certCN}
DNS.8 = *.${certCN}
DNS.9 = *.${certCN#*.}
DNS.10 = ${fqdnSAN4}
DNS.11 = *.${fqdnSAN4}
DNS.12 = ${fqdnSAN5}
DNS.13 = *.${fqdnSAN5}
DNS.14 = ${fqdnSAN6}
DNS.15 = *.${fqdnSAN6}
DNS.16 = ${fqdnSAN7}
DNS.17 = *.${fqdnSAN7}
DNS.18 = localhost
EOF

  if [ -f "${certSaveFolder}/${certName}.pem" ]; then
    echo "-- Deleting existing file '${certSaveFolder}/${certName}.pem'"
    rm -f "${certSaveFolder}/${certName}.pem"
    echo "-- Done"
    echo ""
  fi
  if [ -f "${certSaveFolder}/${certName}-key.pem" ]; then
    echo "-- Deleting existing file '${certSaveFolder}/${certName}-key.pem'"
    rm -f "${certSaveFolder}/${certName}-key.pem"
    echo "-- Done"
    echo ""
  fi

  echo "-- Cert created at ${certSaveFolder}"
  echo ""
  if [ "${fqdnSAN4,,}" != "ignore" ];then
    echo "-- Cert details(v3):"
    # cat "${certSaveFolder}/certdetails_type3.txt"
    # echo ""
    openssl req -newkey rsa:2048 -nodes -keyout "${certSaveFolder}/${certName}-key.pem" -x509 -days 1825 -out "${certSaveFolder}/${certName}.pem" -extensions req_ext -config <( cat "${certSaveFolder}/certdetails_type3.txt" )
    #Removing other cert details files
    rm "${certSaveFolder}/certdetails_type2.txt"
    rm "${certSaveFolder}/certdetails.txt"
  elif [ "${fqdnSAN3,,}" != "ignore" ];then
    echo "-- Cert details(v2):"
    # cat "${certSaveFolder}/certdetails_type2.txt"
    # echo ""
    openssl req -newkey rsa:2048 -nodes -keyout "${certSaveFolder}/${certName}-key.pem" -x509 -days 1825 -out "${certSaveFolder}/${certName}.pem" -extensions req_ext -config <( cat "${certSaveFolder}/certdetails_type2.txt" )
    #Removing other cert details files
    rm "${certSaveFolder}/certdetails_type3.txt"
    rm "${certSaveFolder}/certdetails.txt"
  else
    echo "-- Cert details(v1):"
    # cat "${certSaveFolder}/certdetails.txt"
    # echo ""
    openssl req -newkey rsa:2048 -nodes -keyout "${certSaveFolder}/${certName}-key.pem" -x509 -days 1825 -out "${certSaveFolder}/${certName}.pem" -extensions req_ext -config <( cat "${certSaveFolder}/certdetails.txt" )
    #Removing other cert details files
    rm "${certSaveFolder}/certdetails_type2.txt"
    rm "${certSaveFolder}/certdetails_type3.txt"
  fi
  # cat "${certSaveFolder}/${certName}.pem" | base64 -w 0 > "${certSaveFolder}/${certName}"
  # cat "${certSaveFolder}/${certName}-key.pem" | base64 -w 0 > "${certSaveFolder}/${certName}-key"
  echo "-- Exiting function"
  echo ""
}

echo "[ *** Creating Access Manager Certs *** ]"
amCertFolder="${certsLocation}/am-cert"
createSelfSignedCert "access-manager" "${amCertFolder}" "am" "${fqdn_AM_1}" "${svc_AM}.${namespace_name_1}.svc.cluster.local" "${svc_AM}.${namespace_name_2}.svc.cluster.local" 
echo "-- Done"
printf "\n\n\n\n"

echo "-> Generating Access Manager(AM) Keystore Certificates"
echo "-- es256test ..."
rootSection="es256test"
openssl req -x509 -nodes -days 1825 -sha1 -newkey ec:<(openssl ecparam -name prime256v1) -keyout "${amCertFolder}/${rootSection}-key.pem" -out "${amCertFolder}/${rootSection}.pem" -subj "/C=GB/ST=London/L=London/O=Midships/OU=IT Department/CN=${rootSection}"
echo "-- es384test ..."
rootSection="es384test"
openssl req -x509 -nodes -days 1825 -sha1 -newkey ec:<(openssl ecparam -name secp384r1) -keyout "${amCertFolder}/${rootSection}-key.pem" -out "${amCertFolder}/${rootSection}.pem" -subj "/C=GB/ST=London/L=London/O=Midships/OU=IT Department/CN=${rootSection}"
echo "-- es512test ..."
rootSection="es512test"
openssl req -x509 -nodes -days 1825 -sha1 -newkey ec:<(openssl ecparam -name secp521r1) -keyout "${amCertFolder}/${rootSection}-key.pem" -out "${amCertFolder}/${rootSection}.pem" -subj "/C=GB/ST=London/L=London/O=Midships/OU=IT Department/CN=${rootSection}"
echo "-- selfserviceenc ..."
rootSection="selfserviceenc"
openssl req -x509 -nodes -days 1825 -new -newkey rsa:2048 -sha256 -out selfserviceenc.pem -keyout "${amCertFolder}/${rootSection}-key.pem" -out "${amCertFolder}/${rootSection}.pem" -subj "/C=GB/ST=London/L=London/O=Midships/OU=IT Department/CN=${rootSection}"
echo "-- rsajwtsign ..."
rootSection="rsajwtsign"
openssl req -x509 -nodes -days 1825 -new -newkey rsa:2048 -sha256 -out rsajwtsign.pem -keyout "${amCertFolder}/${rootSection}-key.pem" -out "${amCertFolder}/${rootSection}.pem" -subj "/C=GB/ST=London/L=London/O=Midships/OU=IT Department/CN=${rootSection}"
echo "-- general ..."
rootSection="general"
openssl req -x509 -nodes -days 1825 -new -newkey rsa:2048 -sha256 -keyout "${amCertFolder}/${rootSection}-key.pem" -out "${amCertFolder}/${rootSection}.pem" -subj "/C=GB/ST=London/L=London/O=Midships/OU=IT Department/CN=${rootSection}"
echo "-- test ..."
rootSection="test"
openssl req -x509 -nodes -days 1825 -new -newkey rsa:2048 -sha256 -keyout "${amCertFolder}/${rootSection}-key.pem" -out "${amCertFolder}/${rootSection}.pem" -subj "/C=GB/ST=London/L=London/O=Midships/OU=IT Department/CN=${rootSection}"
echo "-- Done"
printf "\n\n\n\n"
echo ""

echo "[ *** Creating Application Policy Store Certs *** ]"
createSelfSignedCert "app-policy-store" "${certsLocation}/aps-cert" "${svc_CS}.${namespace_name_1}.svc.cluster.local" "${svc_CS}.${namespace_name_2}.svc.cluster.local" "${svc_CS}"
echo "-- Done"
printf "\n\n\n\n"

echo "[ *** Creating Replication Server Certs *** ]"
createSelfSignedCert "repl-server" "${certsLocation}/rs-cert" \
  "${svc_RS}-us.${namespace_name_1}.svc.cluster.local" \
  "${svc_RS}-us.${namespace_name_2}.svc.cluster.local" \
  "${svc_RS}-ts.${namespace_name_1}.svc.cluster.local" \
  "${svc_RS}-ts.${namespace_name_2}.svc.cluster.local" \
  "${svc_RS}-aps.${namespace_name_1}.svc.cluster.local" \
  "${svc_RS}-aps.${namespace_name_2}.svc.cluster.local" \
  "${svc_RS}-aps.${namespace_name_2}.svc.cluster.local" \
  "${svc_RS}-aps.${namespace_name_2}.svc.cluster.local"
echo "-- Done"
printf "\n\n\n\n"

echo "[ *** Creating Token Store Certs *** ]"
createSelfSignedCert "token-store" "${certsLocation}/ts-cert" "${svc_TS}.${namespace_name_1}.svc.cluster.local" "${svc_TS}.${namespace_name_2}.svc.cluster.local" "${svc_TS}"
echo "-- Done"
printf "\n\n\n\n"

echo "[ *** Creating User Store Certs *** ]"
createSelfSignedCert "user-store" "${certsLocation}/us-cert" "${svc_US}.${namespace_name_1}.svc.cluster.local" "${svc_US}.${namespace_name_2}.svc.cluster.local" "${svc_US}"
echo "-- Done"
printf "\n\n\n\n"

echo "[ *** Creating Identity Gateway Certs *** ]"
createSelfSignedCert "identity-gateway" "${certsLocation}/ig-cert" "${svc_IG}.${namespace_name_1}.svc.cluster.local" "${svc_IG}.${namespace_name_2}.svc.cluster.local" "${svc_IG}"
echo "-- Done"
printf "\n\n\n\n"

echo "[ *** Creating Identity Manager (IDM) Certs *** ]"
rsCertFolder="${certsLocation}/idm-cert"
createSelfSignedCert "identity-manager" "${rsCertFolder}" "${fqdn_1}" "${svc_IDM}.${namespace_name_1}.svc.cluster.local" "${svc_IDM}.${namespace_name_2}.svc.cluster.local" "${fqdn_2}"
echo "-- Done"

echo "-> Generating IDM Keystore Certificates"
echo "-- openidm-localhost ..."
rootSection="openidm-localhost"
openssl req -x509 -nodes -days 1825 -new -newkey rsa:2048 -sha256 -keyout "${rsCertFolder}/${rootSection}-key.pem" -out "${rsCertFolder}/${rootSection}.pem" -subj "/C=GB/ST=London/L=London/O=Midships/OU=IT Department/CN=${rootSection}"
echo "-- selfservice ..."
rootSection="selfservice"
openssl req -x509 -nodes -days 1825 -new -newkey rsa:2048 -sha256 -keyout "${rsCertFolder}/${rootSection}-key.pem" -out "${rsCertFolder}/${rootSection}.pem" -subj "/C=GB/ST=London/L=London/O=Midships/OU=IT Department/CN=${rootSection}"
