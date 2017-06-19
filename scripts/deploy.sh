#!/bin/sh
# rsync -r --delete-after --quiet --chmod=F550 \
#     $TRAVIS_BUILD_DIR/client/dist/ \
#     kuzzmi@dev.kuzzmi.com:/var/www/html/dev.kuzzmi.com/

rsync -rR --quiet --chmod=F550 \
    $TRAVIS_BUILD_DIR/api/ \
    kuzzmi@dev.kuzzmi.com:/var/www/app/dev.kuzzmi.com/api/

rsync -rR --quiet --chmod=F550 \
    $TRAVIS_BUILD_DIR/cache/ \
    kuzzmi@dev.kuzzmi.com:/var/www/app/dev.kuzzmi.com/cache/
