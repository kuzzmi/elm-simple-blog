$1/scripts/should_build.sh $1/$2 && npm i -g elm && cd $1/$2 && $1/sysconfcpus/bin/sysconfcpus -n 2 yarn build
