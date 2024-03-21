# **SUMMARY**

This folder contains the Dockerfile required to build the ForgeRock `User Store` component which is built
default on top of `forgerock-ds-base`.

## **PREREQUISITE**

#### [[ Hashicorp Vault ]]
- Ensure the Vault is accessible from the CICD and Kubernetes cluster
- The path to this image secrets in the Vault is of the format `{secrets-engine}/{environment-type}/user-store`. For instance `forgerock/sit/user-store`
- The below secrets must exist in the Vault. Speak with a Midships technical consultant for clarification if you have any queries:
  - amIdentityStoreAdminPassword
  - certificate
  - certificateKey
  - deploymentKey
  - file_dsconfig
  - file_schema
  - javaProperties
  - monitorUserPassword
  - properties
  - rootUserPassword
  - truststorePwd
  - userStoreCertPwd
- Note: <br/>
  When doing replication, ensure the deploymentKey is the same for all DS instances.

## Local Builds

Run the following to build this image locally:

```sh
docker build --tag local/forgerock-user-store \
  --build-arg image_tag=latest \
  --build-arg image_src=local/forgerock-ds-base \
  .
```

**Note** you will need the [forgerock-ds-base](../../base-images/ds-base/readme.md) built into your local docker
registry and called `local/forgerock-ds-base`

## Static Analysis

Static analysis of this repo requires the use of `Hadolint` for Dockerfiles and `Shellcheck` for shell scripts.

### Hadolint

```sh
docker run --rm --interactive hadolint/hadolint < Dockerfile
```

### Shellcheck

```sh
docker run --rm --volume "$PWD:/mnt" koalaman/shellcheck:stable --format=gcc --exclude=SC1091 files/*.sh
```

## Image Testing

The image build process can be tested very basically as follows.

As the build process creates a US-specific env var, we can simply test for the presence of the correct value, e.g.

```sh
docker inspect local/forgerock-user-store | grep "CERT_ALIAS=user-store"
if [[ $? -ne 0 ]]; then 
  echo "FAILED - CERT_ALIAS env var not set to user-store" 
else
  echo "PASSED - CERT_ALIAS env var set to user-store"
fi
```
