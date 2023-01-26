---
layout: post
title: "Docker Multi-Architecture Builds"
date: 2023-01-25
author: "Shawn Isenhart"
---

On the ASR App Dev team we use Docker extensively in our development process.  Our standard project setup is to have a `Dockerfile` and `docker-compose.yml` file defining the base image that we are using for the application while in development, and then use that image for running all of our local tests.  This has removed a huge amount of setup work that we used to need to do whenever we picked up a new project.  In the past it wasn't uncommon to spend the first week of a sprint on a new project just setting up the development environment, getting Ruby installed, fixing all of the weird conflicts that would come up with OpenSSL versions, etc.  In addition, we've leveraged this docker configuration to use Drone for automated testing.

However, with the new M1 Macs this process has hit a snag.  Some of us are now using the new M1s, which use the arm64 architecture, while others are still on previous models of Macs, using the x84 architecture.  Many of our images were built to only work on the x86 architecture, and just don't work on the new M1s.  We can't just switch over the images to only using the arm64 architecture, because that would cause the same problem we currently have for the folks on the x86 architecture.  But we want both architectures to use the same Dockerfile and docker-compose.yml, otherwise we will get into a situation where we could have different setups for different people, which leads to divergent development envrionments - which leads to "but it works on my computer" problems.

Fortunately, Docker has a way to handle this - [multi-platform images](https://docs.docker.com/build/building/multi-platform/).  We can build a single image for both the x86 and arm64 architectures.

To do this, we made the following changes:
 - Created a docker build environment for the multi-platform builds
 - Modified our Dockerfile to support multi-platform differences
 - Change our build command to specify the architectures to build

### Creating a multi-platform build environment

To create a build environment, we needed to run the following command to create a buildx environment and mark it as the default one to use:
`docker buildx create --use --name multiarch`

### Modifying the Dockerfile for multi-platform builds

Modifying our Dockerfile was mostly easy.  If there was no change in how the two architectures were built, then nothing needed to be done.  We had one thing which was different between the two: a set of Oracle InstantClient RPM files.  To handle this, we added the following to our Dockerfile:

```
ARG TARGETARCH
ARG ORACLE_VERSION=19.10
COPY ./rpm/$ORACLE_VERSION/*.$TARGETARCH.rpm /home/oracle/

RUN /usr/bin/alien -i /home/oracle/oracle-instantclient$ORACLE_VERSION-basic-*.$TARGETARCH.rpm
RUN /usr/bin/alien -i /home/oracle/oracle-instantclient$ORACLE_VERSION-devel-*.$TARGETARCH.rpm
RUN /usr/bin/alien -i /home/oracle/oracle-instantclient$ORACLE_VERSION-sqlplus-*.$TARGETARCH.rpm
```

`TARGETARCH` is set to the architecture that you are building.  For us, is either amd64 or arm64.  We needed to do some shenanigans to get that to work with the oracle packages, because the oracle packages are actually named `aarch64` and `x86_64`.  To make that work for us, we just created simlinks from the Docker architecture names pointing to the original oracle files.

### Specifying the architecture when building

Finally, we needed to change our build command to actually build the new new architecture images.  The command we used is:

`docker buildx build --platform linux/amd64,linux/arm64 --push -t asr-docker-local.artifactory.umn.edu/image_name:tag .`

This kicks off two different build processes that you can watch on your terminal, as it builds both the amd64 and arm64 images, then pushes them both up to our artifactory repository.  This takes a while, but when we are done we have a single image that developers on either platform can use.

I hope you find this useful!
