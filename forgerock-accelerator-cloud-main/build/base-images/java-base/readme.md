# Java Base Image

Base image for all the ForgeRock accelerator images.  Built by default on top of `debian:11.6-slim`.

## Local Builds

Run the following to build this image locally:

```sh
docker build --tag local/java-base \
  --build-arg artifactory_baseUrl=sftp://ruhles.freeddns.org:22100 \
  --build-arg artifactory_source=sftp \
  --build-arg artifactory_uname=midships \
  --build-arg artifactory_pword=${SFTP_PWORD} \
  .
```

**Note** you will need the `SFTP_PWORD` environment variable exported in your shell.   The value can be found in the 
[CI / CD Settings page in the Midships GitLab](https://gitlab.com/groups/midships/-/settings/ci_cd).  If this
give you a 404, then you don't have access so contact one of the GitLab Owners.

## Static Analysis

Static analysis of this repo requires the use of `Hadolint` for Dockerfiles and `Shellcheck` for shell scripts.

### Hadolint

```sh
docker run --rm --interactive hadolint/hadolint < Dockerfile
```

### Shellcheck

```sh
docker run --rm --volume "$PWD:/mnt" koalaman/shellcheck:stable --format=gcc --exclude=SC1091 files/*
```

## Image Testing

The image build process can be tested very basically as follows.

As the build process installs NPM, we can simply test for the presence of that binary, e.g.

```sh
docker run --interactive --tty local/java-base /bin/bash -c "java -version"
if [[ $? -ne 0 ]]; then 
  echo "FAILED - java binary folder missing from image" 
else
  echo "PASSED - java binary present in image"
fi
```
