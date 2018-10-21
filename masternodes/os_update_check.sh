#!/bin/bash
COIN_PATH='/usr/local/bin'
function os_update_check() {
echo '#!/bin/bash' > $COIN_PATH/update_os.sh
cat << EOF >> $COIN_PATH/update_os.sh
apt-get update 
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y dist-upgrade  
DEBIAN_FRONTEND=noninteractive apt-get -y autoremove
if [[ -f /var/run/reboot-required ]]
	then echo "\$(date): Update di OS su \$HOSTNAME, riavvio in corso" > /var/log/update_os.log
        shutdown -r now
fi
EOF
crontab -l > /tmp/cron2updos
cat /tmp/cron2updos | grep update_os.sh >/dev/null 2>&1
if [[ $? -eq 0 ]]
 then sed -i '/update_os.sh/d' /tmp/cron2updos
fi
ORA=$(echo $((1 + $RANDOM % 23)))
MIN=$(echo $((1 + $RANDOM % 59)))
echo "$MIN $ORA * * 1 $COIN_PATH/update_os.sh" >> /tmp/cron2updos
crontab /tmp/cron2updos >/dev/null 2>&1
chmod 755 $COIN_PATH/update_os.sh >/dev/null 2>&1
}

os_update_check
