rsync -r --quiet $1/$2 $1/pm2-application.json kuzzmi@dev.kuzzmi.com:/var/www/app/dev.kuzzmi.com/
ssh kuzzmi@dev.kuzzmi.com -i /tmp/deploy_rsa "/bin/bash -c \"source ~/.nvm/nvm.sh && pm2 restart all\""

