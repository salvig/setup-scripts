#!/bin/bash

function mn_update_check() {
echo '#!/bin/bash' > $COIN_PATH/update_$COIN_NAME.sh
cat . ./$1/$1.conf >> $COIN_PATH/update_$COIN_NAME.sh
cat << EOF >> $COIN_PATH/update_$COIN_NAME.sh
cd $TMP_FOLDER >/dev/null 2>&1
wget -q $COIN_TGZ
if [[ $? -ne 0 ]]; then
   echo -e 'Error downloading node.'
   exit 1
fi
if [[ -f $COIN_PATH$COIN_DAEMON ]]; then
	unzip -j $COIN_ZIP *$COIN_DAEMON >/dev/null 2>&1
	MD5SUMOLD=$(md5sum $COIN_PATH$COIN_DAEMON | awk '{print $1}')
	MD5SUMNEW=$(md5sum $COIN_DAEMON | awk '{print $1}')
	pidof $COIN_DAEMON
	RC=$?
	if [[ "$MD5SUMOLD" != "$MD5SUMNEW" && "$RC" -eq 0 ]]; then
		echo -e "Stop running instances"
		for service in $(systemctl | grep $COIN_NAME | awk '{ print $1 }')
		do systemctl stop $service >/dev/null 2>&1
		done
		sleep 3
		RESTARTSYSD=Y
	fi
fi
if [[ "$MD5SUMOLD" != "$MD5SUMNEW" ]];  then
	unzip -o -j $COIN_ZIP *$COIN_DAEMON *$COIN_CLI -d $COIN_PATH >/dev/null 2>&1
	chmod +x $COIN_PATH$COIN_DAEMON $COIN_PATH$COIN_CLI
	if [[ "$RESTARTSYSD" == "Y" ]]
		then echo -e "Restarting 3dcoin services"
		for service in $(systemctl | grep $COIN_NAME | awk '{ print $1 }')
		do systemctl start $service >/dev/null 2>&1
		done
	fi
fi
EOF
crontab -l > /tmp/cron2upd >/dev/null 2>&1
cat /tmp/cron2upd | grep update_$COIN_NAME.sh >/dev/null 2>&1
if [[ $? -eq 0 ]]
 then sed -i "/update_$COIN_NAME.sh/d" /tmp/cron2fix
fi
ORA=$(echo $((1 + $RANDOM % 23)))
MIN=$(echo $((1 + $RANDOM % 59)))
echo "$MIN $ORA * * * $COIN_PATH/update_$COIN_NAME.sh" >> /tmp/cron2upd
crontab /tmp/cron2upd >/dev/null 2>&1
}

declare COINS+=$(ls -1d */ | cut -d "/" -f1)
echo $COINS | grep $1 >/dev/null 2>&1
if [ $? -eq 0 ]
 then . ./$1/$1.conf
 else echo "Such coin $1 is not supported"
 echo "SUpported coins are: $(echo $COINS)"
 exit 1
fi

mn_update_check

