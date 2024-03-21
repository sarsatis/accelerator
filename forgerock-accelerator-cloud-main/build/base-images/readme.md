# ForgeRock Base Images

Base images for all vanilla ForgeRock components.  These are the starting point for creating a customised
ForgeRock deployment.

## Image Dependency Ordering

The images are structured to be dependent on each other, with parent images providing common layers into child images:

```
- java-base
  - tomcat-base
    - am-base
      - fact-base
    - ig-base 
  - ds-base
  - idm-base
```

See the readme.md file for each image for more info.

## Testing Base Images

All base images have a `test.sh` file.  This contains tests to assert certain things are present like environment 
variables, application directories and binaries.

They all use a test helper script that is `sourced` (similar to importing in other languages) to gain access to 
shared functions for executing tests and printing results.
