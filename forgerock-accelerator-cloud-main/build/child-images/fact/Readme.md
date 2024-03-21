# ForgeRock Accelerator Config Exporter

This folder contains the Dockerfile required to build the `ForgeRock Accelerator Config Exporter` component 
which is built default on top of `forgerock-am-base`.

## Local Builds

Run the following to build this image locally:

```sh
docker build --tag local/midships-fact \
  --build-arg image_tag=latest \
  --build-arg image_src=local/nodejs-base \
  .
```

**Note** you will need the [forgerock-fact-base](../../base-images/am-base/readme.md) built into your local docker
registry and called `local/forgerock-fact-base`

## Static Analysis

Static analysis of this repo requires the use of `Hadolint` for Dockerfiles and `Shellcheck` for shell scripts.

### Hadolint

```sh
docker run --rm --interactive hadolint/hadolint < Dockerfile
```

### Shellcheck

```sh
docker run --rm --volume "$PWD:/mnt" koalaman/shellcheck:stable --format=gcc --exclude=SC1091 src/*.sh
```

## Image Testing

The image build process can be tested very basically as follows.

As the build process creates a FACT-specific user, we can simply test for the presence of the expected user, e.g.

```sh
docker inspect local/midships-fact | grep '"User": "fact"'
if [[ $? -ne 0 ]]; then 
  echo "FAILED - USER not set to fact" 
else
  echo "PASSED - USER Set to fact"
fi
```
