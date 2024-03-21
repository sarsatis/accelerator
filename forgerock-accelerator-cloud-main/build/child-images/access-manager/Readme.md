# Access Manager

This folder contains the Dockerfile required to build the ForgeRock `Access Manager` component which is built 
default on top of `forgerock-am-base`.

## Local Builds

Run the following to build this image locally:

```sh
docker build --tag local/forgerock-access-manager \
  --build-arg image_tag=latest \
  --build-arg image_src=local/forgerock-am-base \
  .
```

**Note** you will need the [forgerock-am-base](../../base-images/am-base/readme.md) built into your local docker 
registry and called `local/forgerock-am-base`

## Static Analysis

Static analysis of this repo requires the use of `Hadolint` for Dockerfiles and `Shellcheck` for shell scripts.

### Hadolint

```sh
docker run --rm --interactive hadolint/hadolint < Dockerfile
```

### Shellcheck

```sh
docker run --rm --volume "$PWD:/mnt" koalaman/shellcheck:stable --format=gcc --exclude=SC1091 files/scripts/*.sh
```

## Image Testing

The image build process can be tested very basically as follows.

As the build process creates an AM-specific env var, we can simply test for the presence of the correct value, e.g.

```sh
docker inspect local/forgerock-access-manager | grep "CERT_ALIAS=access-manager"
if [[ $? -ne 0 ]]; then 
  echo "FAILED - CERT_ALIAS env var not set to access-manager" 
else
  echo "PASSED - CERT_ALIAS env var set to access-manager"
fi
```
