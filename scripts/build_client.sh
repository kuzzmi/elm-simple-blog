npm i -g elm
cd $1/$2
( while : ; do date; sleep 60; done ) & yarn build; kill %1
