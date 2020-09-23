ARG RUBY_VERSION=2.4
ARG ALPINE_VERSION=3.6
FROM ruby:${RUBY_VERSION}-alpine${ALPINE_VERSION}
MAINTAINER Techops <techops@adaptly.com>

ARG UPDATED_AT
ARG GIT_SHA
ARG QUAY_EXPIRATION=never

LABEL repo=qurd
LABEL service=qurd
LABEL sha=$GIT_SHA
LABEL quay.expires-after=$QUAY_EXPIRATION

ENV UPDATED_AT=$UPDATED_AT
ENV QUAY_EXPIRATION=$QUAY_EXPIRATION

COPY . /apps/
WORKDIR /apps

RUN apk add --no-cache --update --virtual .cc \
        build-base \
        git \
    && rm -rf .bundle Gemfile.lock \ 
    && bundle package --all \ 
    && bundle install --deployment --local --binstubs=bundler-bin \ 
    && apk del .cc \
    && apk add --no-cache --update bash git openssh-client

RUN ln -sf images/entrypoint.sh entrypoint.sh \
    && chown -R nobody:nogroup bin
ENTRYPOINT ["/apps/entrypoint.sh"]
