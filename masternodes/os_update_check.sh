#!/bin/bash

function os_update_check() {
echo '#!/bin/bash' > $COIN_PATH/update_os.sh
apt-get update >> $COIN_PATH/update_os.sh
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y dist-upgrade >> $COIN_PATH/update_os.sh 
DEBIAN_FRONTEND=noninteractive apt-get -y autoremove >> $COIN_PATH/update_os.sh
if [[ -f /var/run/reboot-required ]]
	then echo "$(date): Update di OS su $HOSTNAME, riavvio in corso" > /var/log/update_os.log
        shutdown -r now
fi
crontab -l > /tmp/cron2updos >/dev/null 2>&1
cat /tmp/cron2updos | grep update_os.sh >/dev/null 2>&1
if [[ $? -eq 0 ]]
 then sed -i '/update_os.sh/d' /tmp/cron2fix
fi
ORA=$(echo $((1 + $RANDOM % 23)))
MIN=$(echo $((1 + $RANDOM % 59)))
echo "$MIN $ORA * * 1 $COIN_PATH/update_os.sh" >> /tmp/cron2updos
crontab /tmp/cron2updos >/dev/null 2>&1
chmod 755 $COIN_PATH/update_os.sh >/dev/null 2>&1
}

os_update_check
