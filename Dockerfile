FROM nginx:1.16-alpine
RUN echo "nginx on apline"

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
RUN apk add --update git python build-base curl bash && echo \"Fixing PhantomJS\" 
RUN yarn install --frozen-lockfile --mutex file:/tmp/.yarn-mutex
#COPY . .
RUN if [ -z \"employee\" ]; then exit 1; fi;
RUN if [ -z \"production\" ]; then exit 1; fi;
#RUN ./build-separated-app.sh 
RUN yarn install --production --frozen-lockfile --mutex file:/tmp/.yarn-mutex

