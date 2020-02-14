#!/bin/sh

snowboard html -o src/core/node/virtual_file_system/api/v1/index.html -c docs/api/v1/blueprints/config.yaml docs/api/v1/blueprints/sushichain.apib
echo "\n"
echo "MANUAL STEP REQUIRED"
echo "\n"
echo "FIX: in the html output please change this line in function authHeader: "
echo 'const header = sample(action).headers.find(header => header.name === "Authorization");'
echo to 'const header = sample(action).headers.find(header => header.name === "Authorization") || {};'
echo "\n"