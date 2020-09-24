#!/bin/sh -ex

if ! type git &>/dev/null; then
  if [ `uname -s` = Linux ]; then
    source /etc/os-release
    case $ID in
      alpine) apk --update add git;;
      debian) apt-get update; apt-get install -y git;;
      *) echo unknown os; exit 1;;
    esac
  else
    echo unsupported os type
    exit 2
  fi
fi
bundle install --binstubs bin
bundle exec rake test
