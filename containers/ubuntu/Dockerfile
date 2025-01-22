FROM ubuntu AS base

ENV PATH=$PATH:/opt/terminalwire/bin

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y ca-certificates git && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
