#!/bin/sh
# /usr/bin/rsync -r --delete-after --quiet --chmod=F550 \
#     $1/client/dist/ \
#     kuzzmi@dev.kuzzmi.com:/var/www/html/dev.kuzzmi.com/

/usr/bin/rsync -r --quiet --chmod=F550 \
    $1/api/ \
    kuzzmi@dev.kuzzmi.com:/var/www/app/dev.kuzzmi.com/api/

/usr/bin/rsync -r --quiet --chmod=F550 \
    $1/cache/ \
    kuzzmi@dev.kuzzmi.com:/var/www/app/dev.kuzzmi.com/cache/
