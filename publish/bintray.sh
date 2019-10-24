#!/bin/bash
set -e

version=$(publish/build_version.sh)
file=Sushi-${version}.tar.gz

function create_package {
  tar cvzf "${file}" src dapps e2e shard.yml version.txt
}

function main {
  credentials=raymanoz:${BINTRAY_API_KEY}
  package=https://api.bintray.com/content/sushichain/SushiChain/SushiChain

  echo "Uploading ${version}..."
  curl -T "${file}" -u"${credentials}" "${package}/${version}/${file}"

  echo 
  echo "Publishing ${version}..."
  curl -X POST -u"${credentials}" "${package}/${version}/publish"
}

create_package
main
