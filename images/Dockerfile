ARG RUBY_VERSION
ARG ALPINE_TAG
FROM ruby:${RUBY_VERSION}-alpine${ALPINE_TAG}
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
    && apk add --no-cache --update bash git openssh-client \
    && rm -rf /var/cache/apk/*

ENTRYPOINT ["/apps/entrypoint.sh"]
