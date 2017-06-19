#!/bin/sh
# rsync -r --delete-after --quiet --chmod=F550 \
#     $TRAVIS_BUILD_DIR/client/dist/ \
#     kuzzmi@dev.kuzzmi.com:/var/www/html/dev.kuzzmi.com/

cd $TRAVIS_BUILD_DIR/api/ && npm install && \
    rsync -rR --quiet --chmod=F550 \
        $TRAVIS_BUILD_DIR/api/ \
        kuzzmi@dev.kuzzmi.com:/var/www/app/dev.kuzzmi.com/api/

cd $TRAVIS_BUILD_DIR/cache/ && npm install && \
    rsync -rR --quiet --chmod=F550 \
        $TRAVIS_BUILD_DIR/cache/ \
        kuzzmi@dev.kuzzmi.com:/var/www/app/dev.kuzzmi.com/cache/
