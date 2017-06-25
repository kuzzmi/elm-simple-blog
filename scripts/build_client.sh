( while : ; do date; sleep 60; done ) & { npm i -g elm && cd $1/$2 && yarn build }; kill %1
