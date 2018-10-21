#!/bin/bash

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
 then . ./$1/$1.conf
 else echo "Such coin $1 is not supported"
 echo "SUpported coins are: $(echo $COINS)"
 exit 1
fi

function sentinel() {
if [[ -z $SENTINEL ]]
  then WHEREIAM=$(pwd) >/dev/null 2>&1
  cd >/dev/null 2>&1
  apt-get -y install python-virtualenv >/dev/null 2>&1
  export LC_ALL="en_US.UTF-8" >/dev/null 2>&1
  export LC_CTYPE="en_US.UTF-8" >/dev/null 2>&1
  git clone $GITSENTINEL >/dev/null 2>&1
  cd $SENTINELREPO >/dev/null 2>&1
  virtualenv ./venv >/dev/null 2>&1
  ./venv/bin/pip install -r requirements.txt >/dev/null 2>&1
  venv/bin/python bin/sentinel.py >/dev/null 2>&1
  sleep 3 >/dev/null 2>&1
  crontab 'crontab.txt' >/dev/null 2>&1
  cd $WHEREIAM >/dev/null 2>&1
fi
}

function check_distro() {
if [[ $(lsb_release -i) != *Ubuntu* ]]; then
  echo -e "${RED}You are not running Ubuntu. This script is meant for Ubuntu.${NC}"
  exit 1
fi
}

function check_user() {
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi
}

function apt_update() {
echo
echo -e "${GREEN}Checking and installing operating system updates. It may take awhile ...${NC}"
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y dist-upgrade >/dev/null 2>&1 
DEBIAN_FRONTEND=noninteractive apt-get -y install zip unzip curl >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -y autoremove >/dev/null 2>&1
}

function check_swap() {
SWAPSIZE=$(cat /proc/meminfo | grep SwapTotal | awk '{print $2}')
FREESPACE=$(df / | tail -1 | awk '{print $4}')
if [ $SWAPSIZE -lt 4000000 ]
  then if [ $FREESPACE -gt 6000000 ]
    then dd if=/dev/zero of=/bigfile.swap bs=250MB count=16 
    chmod 600 /bigfile.swap
    mkswap /bigfile.swap
    swapon /bigfile.swap
    echo '/bigfile.swap none swap sw 0 0' >> /etc/fstab
    else echo 'Swap seems smaller than recommended. It cannot be increased because of lack of space'
    fi
fi  
}

function check_firewall() {
declare -a SERVICES=$(netstat -ntpl| grep -v 127.0.[0-99].[0-99] |grep -v '::1' | grep [0-9]|awk '{print $4}'|cut -d":" -f2)
for PORT in ${SERVICES};do echo -e "${GREEN} $(lsof -i:$PORT|tail -1 | awk '{print $1}') is listening on $PORT; enabling ...${NC}"; ufw allow $PORT >/dev/null 2>&1; done
echo -e "${GREEN}Enabling $COIN_PORT ...${NC}"; ufw allow $COIN_PORT >/dev/null 2>&1
ufw -f enable
}

function download_node() {
echo -e "${GREEN}Downloading and Installing VPS $COIN_NAME Daemon${NC}"
apt -y install zip unzip curl >/dev/null 2>&1
sleep 5
cd $TMP_FOLDER >/dev/null 2>&1
wget -q $COIN_TGZ
if [[ $? -ne 0 ]]; then
	echo -e 'Error downloading node. Please contact support'
	exit 1
fi
case $COIN_ZIP in
  *.tar.gz*)
    tar xzvf $COIN_ZIP
    find . -name $COIN_DAEMON | xargs mv -t $COIN_PATH >/dev/null 2>&1
    find . -name $COIN_CLI | xargs mv -t $COIN_PATH >/dev/null 2>&1
    chmod +x $COIN_PATH$COIN_DAEMON $COIN_PATH$COIN_CLI
    ;;
  *.zip*)
    unzip -o -j $COIN_ZIP *$COIN_DAEMON *$COIN_CLI -d $COIN_PATH >/dev/null 2>&1
    chmod +x $COIN_PATH$COIN_DAEMON $COIN_PATH$COIN_CLI
    ;;
esac
}

get_ip() {
NODEIP=$(curl -s4 icanhazip.com)
}

function create_config() {
  mkdir $CONFIGFOLDER$IP_SELECT >/dev/null 2>&1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  if [[ -z "$IP_SELECT" ]]; then
   RPC_PORT=$RPC_PORT
   else let RPC_PORT=$RPC_PORT-$IP_SELECT
  fi
  cat << EOF > $CONFIGFOLDER$IP_SELECT/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcport=$RPC_PORT
server=1
daemon=1
port=$COIN_PORT
EOF
}

function create_key() {
$COIN_PATH$COIN_DAEMON -daemon >/dev/null 2>&1
sleep 60
if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
 echo -e "${RED}$COIN_NAME server couldn not start. Check /var/log/syslog for errors.{$NC}"
 exit 1
fi
COUNT=0
while [[ "$COUNT" -ne "20" ]]; do COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
 if [ "$?" -gt "0" ];
    then echo -e "${RED}Wallet not fully loaded. Let us wait and try again to generate the GEN Key${NC}"
    sleep 20
    let COUNT=${COUNT}+1 
    else COUNT=20
 fi
done
$COIN_PATH$COIN_CLI stop >/dev/null 2>&1
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $CONFIGFOLDER/$CONFIG_FILE
  if [[ "$NODEIP" =~ [A-Za-z] ]]; then
    NODEIP=[$NODEIP]
    RPCBIND=[::1]
   else RPCBIND=127.0.0.1
  fi
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE
maxconnections=64
bind=$NODEIP
rpcbind=$RPCBIND
rpcallow=$RPCBIND
masternode=1
externalip=$NODEIP:$COIN_PORT
masternodeprivkey=$COINKEY
EOF
}

function configure_systemd() {
  cat << EOF > /etc/systemd/system/$COIN_NAME.service
[Unit]
Description=$COIN_NAME$IP_SELECT service
After=network.target
[Service]
User=root
Group=root
Type=forking
ExecStart=$COIN_PATH$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
ExecStop=-$COIN_PATH$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $COIN_NAME$IP_SELECT.service >/dev/null 2>&1
systemctl start $COIN_NAME$IP_SELECT.service
sleep 8
netstat -napt | grep LISTEN | grep $NODEIP | grep $COIN_DAEMON >/dev/null 2>&1
 if [[ $? -ne 0 ]]; then
   ERRSTATUS=TRUE
 fi
}

function important_information() {
 clear
 echo
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${CYAN}$COIN_NAME linux  vps setup${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${GREEN}$COIN_NAME Masternode is up and running listening on port: ${NC}${RED}$COIN_PORT${NC}."
 echo -e "${GREEN}Configuration file is: ${NC}${RED}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 echo -e "${GREEN}VPS_IP: ${NC}${RED}$NODEIP:$COIN_PORT${NC}"
 echo -e "${GREEN}MASTERNODE GENKEY is: ${NC}${RED}$COINKEY${NC}"
 echo -e "${BLUE}================================================================================================================================"
 echo -e "${CYAN}Stop, start and check your $COIN_NAME instance${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${PURPLE}Instance  start${NC}"
 echo -e "${GREEN}systemctl start $COIN_NAME.service${NC}"
 echo -e "${PURPLE}Instance  stop${NC}"
 echo -e "${GREEN}systemctl stop $COIN_NAME.service${NC}"
 echo -e "${PURPLE}Instance  check${NC}"
 echo -e "${GREEN}systemctl status $COIN_NAME.service${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${CYAN}Ensure Node is fully SYNCED with BLOCKCHAIN before start your masternode from hot wallet .${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${GREEN}$COIN_CLI mnsync status${NC}"
 echo -e "${YELLOW}It is expected this line: \"IsBlockchainSynced\": true ${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${CYAN}Check masternode status${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${GREEN}$COIN_CLI masternode status${NC}"
 echo -e "${GREEN}$COIN_CLI getinfo${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 if [[ "$ERRSTATUS" == "TRUE" ]]; then
    echo -e "${RED}$COIN_NAME seems not running, please investigate. Check its status by running the following commands as root:${NC}"
    echo -e "systemctl status $COIN_NAME.service"
    echo -e "${RED}You can restart it by firing following command (as root):${NC}"
    echo -e "${GREEN}systemctl start $COIN_NAME.service${NC}"
    echo -e "${RED}Check errors by runnig following commands:${NC}"
    echo -e "${GREEN}less /var/log/syslog${NC}"
    echo -e "${GREEN}journalctl -xe${NC}"
 fi
echo -e "Copy the info you need, then press any key to reboot"
read -e tasto
case $tasto in
 *)
  shutdown -r now
  ;;
esac
}

function mn_update_check() {
echo '#!/bin/bash' > $COIN_PATH/update_$COIN_NAME.sh
cat ./$1/$1.conf >> $COIN_PATH/update_$COIN_NAME.sh
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
		then echo "$(date) : Update di $COIN su $HOSTNAME verificare lo stato" > /var/log/update_demone.log
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
chmod 755 $COIN_PATH/update_$COIN_NAME.sh >/dev/null 2>&1
}

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

function setup_node() {
  check_distro
  check_user
  apt_update
  check_swap
  check_firewall
  download_node
  get_ip
  create_config
  create_key
  update_config
  configure_systemd
  sentinel
  mn_update_check
  os_update_check
  important_information
}

setup_node
