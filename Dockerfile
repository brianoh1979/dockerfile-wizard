#Adding in comment to trigger fresh build
FROM    ubuntu:latest

RUN     export DEBIAN_FRONTEND=noninteractive && \
        ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime && \
        apt-get update -y && \
        apt-get install -y \
            pandoc python3 ruby nodejs virtualbox golang gimp redis \
            mongodb postgresql
