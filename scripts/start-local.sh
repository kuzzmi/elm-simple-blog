#!/bin/sh
pm2 start pm2-application.json --env dev
pm2 delete cache-service
cd client
open http://localhost:8000
yarn dev
