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

FROM nginx:1.16-alpine
#COPY img /var/www/php
#COPY Makefile /var/www/php
#COPY scripts /var/www/php  

FROM node:12.4-alpine
RUN if [ -z "employee" ]; then exit 1; fi;
RUN apk add --update --no-cache tzdata && apk del tzdata
RUN apk add --update --no-cache bash build-base curl git python
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --mutex file:/tmp/.yarn-mutex
RUN npm set progress=false
RUN echo \"http://dl-2.alpinelinux.org/alpine/edge/main\" > /etc/apk/repositories
RUN echo \"http://dl-2.alpinelinux.org/alpine/edge/community\" >> /etc/apk/repositories
RUN echo \"http://dl-2.alpinelinux.org/alpine/edge/testing\" >> /etc/apk/repositories
#COPY stack-fix.c /lib/
#RUN set -ex     && gcc  -shared -fPIC /lib/stack-fix.c -o /lib/stack-fix.so
#RUN apk add rsync
RUN apk add --update git python build-base curl bash && echo \"Fixing PhantomJS\" 
RUN yarn install --frozen-lockfile --mutex file:/tmp/.yarn-mutex
COPY . .
#RUN npm run postinstall
RUN if [ -z \"employee\" ]; then exit 1; fi;
RUN if [ -z \"production\" ]; then exit 1; fi;
RUN ./build-separated-app.sh 
RUN yarn install --production --frozen-lockfile --mutex file:/tmp/.yarn-mutex
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

#ENTRYPOINT ["bazel"]

#FROM alpine:latest  
#RUN apk --no-cache add ca-certificates
#WORKDIR /root/
#COPY --from=0 /go/src/github.com/alexellis/href-counter/app .
#CMD ["./app"]  

#FROM python:3.7-alpine3.7
#COPY . /app
#ENTRYPOINT [“python”, “./app/my_script.py”, “my_var”]
