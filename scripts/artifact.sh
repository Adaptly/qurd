#!/bin/bash
set -e
bundle package --all
bundle install --binstubs bundler-bin --deployment --local --without development test
echo ${BUILD_NUMBER} > .release.txt
git rev-parse --verify HEAD >> .release.txt
rm -rf release
mkdir -p release
tar -cvzf release/qurd-${BUILD_NUMBER}.tgz --exclude release * .release.txt .bundle .ruby-version
