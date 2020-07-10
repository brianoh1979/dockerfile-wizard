ARG OPENJDK_TAG=8u232
FROM openjdk:${OPENJDK_TAG} AS base1

ARG SBT_VERSION=1.3.7

# Install sbt
RUN \
  curl -L -o sbt-$SBT_VERSION.deb https://dl.bintray.com/sbt/debian/sbt-$SBT_VERSION.deb && \
  dpkg -i sbt-$SBT_VERSION.deb && \
  rm sbt-$SBT_VERSION.deb && \
  apt-get update && \
  apt-get install sbt && \
  sbt sbtVersion

FROM php:7.0-apache  
COPY img /var/www/php
COPY Makefile /var/www/php
COPY scripts /var/www/php  

