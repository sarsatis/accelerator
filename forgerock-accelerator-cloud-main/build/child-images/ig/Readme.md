# ForgeRock Identity Gateway (IG)

This folder contains the Dockerfile required to build the `ForgeRock Identity Gateway (IG)` component which 
is built default on top of `forgerock-ig-base`.

## Local Builds

Run the following to build this image locally:

```sh
docker build --tag local/forgerock-ig \
  --build-arg image_tag=latest \
  --build-arg image_src=local/forgerock-ig-base \
  .
```

**Note** you will need the [forgerock-ig-base](../../base-images/ig-base/readme.md) built into your local docker
registry and called `local/forgerock-ig-base`

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

As the build process creates a IG-specific user, we can simply test for the presence of the expected user, e.g. 
e.g.

```sh
docker inspect local/forgerock-ig | grep '"User": "ig"'
if [[ $? -ne 0 ]]; then 
  echo "FAILED - USER not set to ig" 
else
  echo "PASSED - USER Set to ig"
fi
```
