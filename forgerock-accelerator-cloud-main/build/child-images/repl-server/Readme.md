# Replication Server

This folder contains the Dockerfile required to build the ForgeRock `Replication Server` component which is built
default on top of `forgerock-ds-base`.

## Local Builds

Run the following to build this image locally:

```sh
docker build --tag local/forgerock-repl-server \
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

As the build process creates a RS-specific env var, we can simply test for the presence of the correct value, e.g.

```sh
docker inspect local/forgerock-repl-server | grep "CERT_ALIAS=repl-server"
if [[ $? -ne 0 ]]; then 
  echo "FAILED - CERT_ALIAS env var not set to repl-server" 
else
  echo "PASSED - CERT_ALIAS env var set to repl-server"
fi
```
