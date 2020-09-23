#!/bin/bash -x

if [[ $1 =~ sh$ ]]; then
  exec $@
else
  bundle exec ./bin/qurd /etc/qurd/qurd-config.yaml $@
fi