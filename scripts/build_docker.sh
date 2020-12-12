#!/bin/sh -uex

# Build Axentro static binaries for GNU/Linux x86_64 via Docker

READLINK=`which readlink`

MY_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
test -d $MY_DIR/../bin || mkdir $MY_DIR/../bin
BIN_DIR=$(cd $MY_DIR/../bin && pwd -P)

cd "$BIN_DIR"

if [ -d Axentro ]; then
  git -C Axentro clean -fd
else
  git clone https://github.com/Axentro/Axentro.git
fi

if [ ! -d "crystal-0.35.1-1" ]; then
  curl -L -o crystal-0.35.1-1-linux-x86_64.tar.gz https://github.com/crystal-lang/crystal/releases/download/0.35.1/crystal-0.35.1-1-linux-x86_64.tar.gz
  tar -xzvf crystal-0.35.1-1-linux-x86_64.tar.gz
fi

########################
# ubuntu:16.04
########################
docker run --rm -it -v $PWD:/mnt ubuntu:16.04 /bin/bash -c "
adduser --disabled-password --shell /bin/bash --gecos \"User\" $USER
set -x ;
export PATH=/mnt/crystal-0.35.1-1/bin:\$PATH ;
apt update -qq ;
DEBIAN_FRONTEND=\"noninteractive\" TZ=\"Europe/London\" apt install -y curl libsqlite3-dev libevent-dev libpcre3-dev libssl-dev libxml2-dev libyaml-dev libgmp-dev libz-dev git build-essential ;
cd /mnt/Axentro ;
su $USER -c 'PATH=/mnt/crystal-0.35.1-1/bin:\$PATH shards install --production' ;
su $USER -c 'PATH=/mnt/crystal-0.35.1-1/bin:\$PATH shards build --no-debug --static --release --production' ;
"

cp Axentro/bin/axe* $BIN_DIR/
test -d axentro-linux-x86_64 || mkdir axentro-linux-x86_64
cp Axentro/bin/axe* axentro-linux-x86_64 && tar -cJf axentro-linux-x86_64.tar.xz axentro-linux-x86_64

rm -rf Axentro axentro-linux-x86_64 crystal-0.35.1-1 crystal-0.35.1-1-linux-x86_64.tar.gz

cd "$OLDPWD"
