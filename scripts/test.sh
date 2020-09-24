#!/bin/bash -ex

bundle install --binstubs bin
bundle exec rake test
