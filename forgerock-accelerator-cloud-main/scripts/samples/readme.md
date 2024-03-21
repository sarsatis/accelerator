#### `sample-generate-offline-certificates.sh`
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
      The service name of the config store component -
        e.g. forgerock-app-policy-store
      Required

  -svcCS "service-name-user-store"
      The service name of the config store component -
        e.g. forgerock-app-policy-store
      Required

  -svcCS "service-name-token-store"
      The service name of the config store component -
        e.g. forgerock-app-policy-store
      Required

  -svcCS "service-name-relication-server"
      The service name of the config store component -
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
      
**Example command**
```
./sample-generate-offline-certificates.sh \
  -ns1 "forgerock" \
  -ns2 "forgerock-dc2" \
  -amfqdn1 "am1.midships.io" \
  -amfqdn2 "am2.midships.io" \
  -idmfqdn1 "idm1.midships.io" \
  -idmfqdn2 "idm2.midships.io" \
  -svcAM forgerock-access-manager \
  -svcUS forgerock-user-store \
  -svcTS forgerock-token-store \
  -svcCS forgerock-app-policy-store \
  -svcRS forgerock-repl-server \
  -svcIDM forgerock-idm \
  -svcIG forgerock-ig
```

#### `sample-vault-post-deploy.sh`
_This script can be used to do creae a execute standard Hashicorp Vault tasks including adding or updating secrets under the created Secrets Engine. Below is a summary of the parameters:_
- `${1}`  Script action. Can be:
  - `init` to initialize a Hashicorp Vault
  - `create-se` to create KV2 Secrets Engine
  - `add-secrets` add secrets to Hashicorp Vault Secrets Store
  - `del-secrets` to delete secrets from the Hashicorp Vault
- `${2}` The Hashicorp Vault URL
- `${3}` The Hashicorp Vault Token
- `${4}` The Name of the KV Secrets Engine to be created in the Vault
- `${5}` The ForgeRock Access Manafger Load Balancer domain name
- `${6}` A string of the Environment Type. For instance `DEV`, `SIT`, etc.
- `${7}` The namespace of the deployment in the Kubernetes cluster the ForgeRock Solution will be deployed inetOrgPerson
- `${8}` A `yes` or `no` string to decide if to add the Client Name to the secrets path. See script for details.
- `${9}` The Client name, ony used where you have multiple clients/customer saving to the same Vault Secrets Store
- `${10}` A `yes` or `no` string to decide if certificates show be regenerated

**SAMPLE For Creating A Secrets Engine called `forgerock`**
```
./post-deploy.sh \
create-se \
"https://midships-vault.vault.6ab12ea5-c7af-456f-81b5-e0aaa5c9df5e.aws.hashicorp.cloud:8200" \
"s.bLPQRSnS8Ht1rV9f00LfmZoO.MV86d" \
forgerock \
"am.d2portal.co.uk" \
sit \
forgerock \
no \
"" \
yes
```

**SAMPLE For Adding Secrets for `SIT` environment**
```
./post-deploy.sh \
add-secrets \
"https://midships-vault.vault.6ab12ea5-c7af-456f-81b5-e0aaa5c9df5e.aws.hashicorp.cloud:8200" \
"s.bLPQRSnS8Ht1rV9f00LfmZoO.MV86d" \
forgerock \
"am.d2portal.co.uk" \
SIT \
forgerock \
no \
"" \
no
```

