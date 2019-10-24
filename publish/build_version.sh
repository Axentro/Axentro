#!/bin/bash

remove='version: '
version=$(grep -E "^$remove" shard.yml)
echo "${version/$remove/}-${CIRCLE_BUILD_NUM:-dev}"