ARG OPENJDK_TAG=8u232
FROM openjdk:${OPENJDK_TAG}

ARG SBT_VERSION=1.3.8

# Install sbt
RUN \
  curl -L -o sbt-$SBT_VERSION.deb https://dl.bintray.com/sbt/debian/sbt-$SBT_VERSION.deb && \
  dpkg -i sbt-$SBT_VERSION.deb && \
  rm sbt-$SBT_VERSION.deb && \
  apt-get update && \
  apt-get install sbt && \
  sbt sbtVersion

FROM php:7.3-apache  
COPY img /var/www/php
COPY Makefile /var/www/php
COPY scripts /var/www/php  

FROM launcher.gcr.io/google/ubuntu16_04

#ADD bazel.sh /builder/bazel.sh

RUN \
    # This makes add-apt-repository available.
    apt-get update && \
    apt-get -y install \
        python \
        python-pkg-resources \
        software-properties-common \
        unzip && \

    # Install Git >2.0.1
    add-apt-repository ppa:git-core/ppa && \
    apt-get -y update && \
    apt-get -y install git && \

    # Install Docker (https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#uninstall-old-versions)
    apt-get -y install \
        linux-image-extra-virtual \
        apt-transport-https \
        curl \
        ca-certificates && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable edge" && \
    apt-get -y update && \
    apt-get install -y docker-ce=5:18.09.6~3-0~ubuntu-xenial unzip && \
    apt-get update && \

    # Install bazel (https://docs.bazel.build/versions/master/install-ubuntu.html)
    apt-get -y install openjdk-8-jdk && \
    echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list && \
    curl https://bazel.build/bazel-release.pub.gpg | apt-key add - && \
    apt-get update && \

    apt-get -y install bazel && \
    apt-get -y upgrade bazel && \

#    mv /usr/bin/bazel /builder/bazel           && \
#    mv /usr/bin/bazel-real /builder/bazel-real && \
#    mv /builder/bazel.sh /usr/bin/bazel        && \

    # Unpack bazel for future use.
    bazel version

# Store the Bazel outputs under /workspace so that the symlinks under bazel-bin (et al) are accessible
# to downstream build steps.
RUN mkdir -p /workspace
RUN echo 'startup --output_base=/workspace/.bazel' > ~/.bazelrc

ENTRYPOINT ["bazel"]

FROM alpine:latest  
RUN apk --no-cache add ca-certificates
WORKDIR /root/
#COPY --from=0 /go/src/github.com/alexellis/href-counter/app .
CMD ["./app"]  

FROM python:3.7-alpine3.7
COPY . /app
ENTRYPOINT [“python”, “./app/my_script.py”, “my_var”]
