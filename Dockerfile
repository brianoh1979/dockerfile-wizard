FROM node:12.4-alpine as base

WORKDIR /data/opt/frontend

RUN apk add --update --no-cache tzdata && cp /usr/share/zoneinfo/Europe/Paris /etc/localtime && echo "Europe/Paris" > /etc/timezone && apk del tzdata

RUN apk add --update --no-cache \
  bash \
  build-base \
  curl \
  git \
  python

# Layering the package installation
COPY package.json yarn.lock ./

RUN yarn install --frozen-lockfile --mutex file:/tmp/.yarn-mutex

RUN npm set progress=false

# Update apk repositories
RUN echo "http://dl-2.alpinelinux.org/alpine/edge/main" > /etc/apk/repositories
RUN echo "http://dl-2.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
RUN echo "http://dl-2.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

# Fixing alpine stack for lib-sass #https://github.com/sass/node-sass/issues/2031
COPY stack-fix.c /lib/
RUN set -ex \
    && gcc  -shared -fPIC /lib/stack-fix.c -o /lib/stack-fix.so
ENV LD_PRELOAD /lib/stack-fix.so

# Build
FROM base as local

RUN apk add --update --no-cache tzdata && cp /usr/share/zoneinfo/Europe/Paris /etc/localtime && echo "Europe/Paris" > /etc/timezone && apk del tzdata
RUN apk add rsync

# Fix phantom
RUN apk add --update git python build-base curl bash && \
  echo "Fixing PhantomJS" && \
    curl -Ls "https://github.com/dustinblackman/phantomized/releases/download/2.1.1/dockerized-phantomjs.tar.gz" | tar xz -C /

WORKDIR /data/opt/

ENV NPM_PATH=/data/opt/
ENV PATH=$PATH:/data/opt/node_modules/.bin

COPY package.json yarn.lock ./

RUN yarn install --frozen-lockfile --mutex file:/tmp/.yarn-mutex

WORKDIR /data/opt/frontend

COPY . .

# Fixing patch-package that don't find patch files after yarn install
RUN npm run postinstall

CMD npm run serve

# Builder
FROM local as build

RUN npm run build
WORKDIR /data/opt/frontend/dist
RUN yarn install --production --frozen-lockfile --mutex file:/tmp/.yarn-mutex


# Build separated app
FROM local as build-separated-app

ARG APP_NAME
ARG ANGULAR_CONFIG
RUN if [ -z "$APP_NAME" ]; then exit 1; fi;
RUN if [ -z "$ANGULAR_CONFIG" ]; then exit 1; fi;

RUN ./tools/build-separated-app.sh ${APP_NAME} ${ANGULAR_CONFIG}
WORKDIR /data/opt/frontend/dist/${APP_NAME}
RUN yarn install --production --frozen-lockfile --mutex file:/tmp/.yarn-mutex


# Dist separated app
FROM nginx:1.16-alpine as dist-separated-app

ARG APP_NAME
RUN if [ -z "$APP_NAME" ]; then exit 1; fi;

COPY --from=build-separated-app /data/opt/frontend/dist/${APP_NAME} /data/opt/frontend/dist/${APP_NAME}

# Copy artifacts which contain build stats
COPY --from=build-separated-app /data/opt/frontend/dist/artifacts /data/opt/frontend/dist/artifacts

# Copy sources for the homepage
COPY --from=build-separated-app /data/opt/frontend/projects/home/* /data/opt/frontend/dist/home/

# Build fast
FROM local as build-fast

RUN npm run build:fast
WORKDIR /data/opt/frontend/dist
RUN yarn install --production --frozen-lockfile --mutex file:/tmp/.yarn-mutex


# Dist
FROM nginx:1.16-alpine as dist

RUN apk add --update --no-cache curl

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s \
	CMD curl -f http://localhost/FRONT_HASH || exit 1

COPY --from=build /data/opt/frontend/dist /data/opt/frontend/dist
COPY --from=build /data/opt/frontend/config/nginx-docker.conf /etc/nginx/conf.d/default.conf

# Dist separated apps
# This steps needs spearated app docker images available (front-admin, front-health etc...)
FROM nginx:1.16-alpine as dist-separated-apps

RUN apk add --update --no-cache curl

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s \
	CMD curl -f http://localhost/FRONT_HASH || exit 1

# These "--from" refer to docker images that are loaded before this build, not a multi-stage step
# The different apps are built in different docker images. This step only copy the generated sources
COPY --from=front-adhesion /data/opt/frontend/dist/adhesion /data/opt/frontend/dist/adhesion
COPY --from=front-admin /data/opt/frontend/dist/admin /data/opt/frontend/dist/admin
COPY --from=front-health /data/opt/frontend/dist/health /data/opt/frontend/dist/health
COPY --from=front-employer /data/opt/frontend/dist/employer /data/opt/frontend/dist/employer
COPY --from=front-employee /data/opt/frontend/dist/employee /data/opt/frontend/dist/employee
COPY --from=front-portal /data/opt/frontend/dist/portal /data/opt/frontend/dist/portal
COPY --from=front-support /data/opt/frontend/dist/support /data/opt/frontend/dist/support

# Copy artifacts which contain build stats
COPY --from=front-adhesion /data/opt/frontend/dist/artifacts /data/opt/frontend/dist/artifacts
COPY --from=front-admin /data/opt/frontend/dist/artifacts /data/opt/frontend/dist/artifacts
COPY --from=front-health /data/opt/frontend/dist/artifacts /data/opt/frontend/dist/artifacts
COPY --from=front-employer /data/opt/frontend/dist/artifacts /data/opt/frontend/dist/artifacts
COPY --from=front-employee /data/opt/frontend/dist/artifacts /data/opt/frontend/dist/artifacts
COPY --from=front-portal /data/opt/frontend/dist/artifacts /data/opt/frontend/dist/artifacts
COPY --from=front-support /data/opt/frontend/dist/artifacts /data/opt/frontend/dist/artifacts

COPY --from=front-health /data/opt/frontend/dist/health/FRONT_HASH /data/opt/frontend/dist/FRONT_HASH
COPY config/nginx-docker.conf /etc/nginx/conf.d/default.conf

RUN ln -s /data/opt/frontend/dist/health/assets /data/opt/frontend/dist/assets

# Copy sources for the homepage
COPY --from=front-health /data/opt/frontend/dist/home/* /data/opt/frontend/dist/


WORKDIR /data/opt/frontend/dist

# Dist fast
FROM nginx:1.16-alpine as dist-fast

RUN apk add --update --no-cache curl

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s \
	CMD curl -f http://localhost/FRONT_HASH || exit 1

COPY --from=build-fast /data/opt/frontend/dist /data/opt/frontend/dist
COPY --from=build-fast /data/opt/frontend/config/nginx-docker.conf /etc/nginx/conf.d/default.conf

WORKDIR /data/opt/frontend/dist

# Stats
FROM base as stats

ENV NPM_PATH=/data/opt/
ENV PATH=$PATH:/data/opt/node_modules/.bin

WORKDIR /data/opt/frontend

COPY . .

RUN npm run build:stats:prod

# e2e
FROM cypress/base:13.3.0 as e2e

RUN apt-get update && apt-get install -y postgresql-client

WORKDIR /data/opt/frontend

ENV CI=true

COPY --from=local /data/opt/frontend /data/opt/frontend
RUN npm rb
RUN node_modules/.bin/cypress install


RUN echo "Editing Cypress file at /root/.cache/Cypress/*/Cypress/resources/app/packages/server/config/app.yml"


COPY tools/sorry_cypress.sh .
RUN ./sorry_cypress.sh
