#!/bin/sh
# /usr/bin/rsync -r --delete-after --quiet --chmod=F550 \
#     $1/client/dist/ \
#     kuzzmi@dev.kuzzmi.com:/var/www/html/dev.kuzzmi.com/
TRAVIS_BUILD_DIR=$1

rsync -r --quiet --chmod=F550 \
    $TRAVIS_BUILD_DIR/api/ \
    kuzzmi@dev.kuzzmi.com:/var/www/app/dev.kuzzmi.com/api/

rsync -r --quiet --chmod=F550 \
    $TRAVIS_BUILD_DIR/cache/ \
    kuzzmi@dev.kuzzmi.com:/var/www/app/dev.kuzzmi.com/cache/

rsync --quiet --chmod=F550 \
    $TRAVIS_BUILD_DIR/pm2-application.json \
    kuzzmi@dev.kuzzmi.com:/var/www/app/dev.kuzzmi.com/
