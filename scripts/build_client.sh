./should_build.sh $1/$2 && npm i -g elm && cd $1/$2 && yarn install && $1/sysconfcpus/bin/sysconfcpus -n 2;yarn build
