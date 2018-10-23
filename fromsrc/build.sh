#!/bin/bash

COIN_NAME=$1
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m" 
PURPLE="\033[0;35m"
RED='\033[0;31m'
GREEN="\033[0;32m"
NC='\033[0m'
MAG='\e[1;35m'

declare COINS+=$(ls -1d */ | cut -d "/" -f1)
echo $COINS | grep $1 >/dev/null 2>&1
if [ $? -eq 0 ]
 then . ./$1/$1.src
 else echo "Such coin $1 is not supported"
 echo "SUpported coins are: $(echo $COINS)"
 exit 1
fi

build_coin() {
cd $HOME/src
git clone $GITHUB
chmod -R 755 $GITREPO
cd $GITREPO
if [[ -d depends ]]
	then cd depends
	make NO_QT=1
	cd ..
	./autogen.sh
	CONFIG_SITE=$PWD/depends/x86_64-pc-linux-gnu/share/config.site ./configure --without-gui --disable-tests --prefix=$HOME/build/$COIN_NAME
	make install-strip
fi
}

create_package() {
cd $HOME/build
tar zcvf $COIN_NAME.tar.gz $COIN_NAME/
mv $COIN_NAME.tar.gz $HOME/setup-scripts/fromsrc/$COIN_NAME
cd $HOME/setup-scripts
git pull
git add .
git commit -m "Added $COIN_NAME binaries package"
git push ssh://git@github.com/salvig/setup-scripts.git
}


build_coin
create_package
unset COINS
