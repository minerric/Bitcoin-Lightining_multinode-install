#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="Bitcoin_Lightning.conf"
BITCOIN_LIGHTNING_DAEMON="/usr/local/bin/Bitcoin-Lightningd"
BITCOIN_LIGHTNING_REPO="https://github.com/Bitcoinlightning/Bitcoin-Lightning.git"
DEFAULTBITCOIN_LIGHTNINGPORT=17127
DEFAULTBITCOIN_LIGHTNINGUSER="BitcoinLightning"
NODEIP=$(curl -s4 icanhazip.com)


RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $BITCOIN_LIGHTNING_DAEMON)" ] || [ -e "$BITCOIN_LIGHTNING_DAEMOM" ] ; then
  echo -e "${GREEN}\c"
  read -e -p "Bitcoin_Lightning is already installed. Do you want to add another MN? [Y/N]" NEW_BITCOIN_LIGHTNING
  echo -e "{NC}"
  clear
else
  NEW_BITCOIN_LIGHTNING="new"
fi
}

function prepare_system() {

echo -e "Prepare the system to install Bitcoin_Lightning master node."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget pwgen curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
libminiupnpc-dev libgmp3-dev >/dev/null 2>&1
clear
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git pwgen curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev"
 exit 1
fi

clear
echo -e "Checking if swap space is needed."
PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
SWAP=$(free -g|awk '/^Swap:/{print $2}')
if [ "$PHYMEM" -lt "2" ] && [ -n "$SWAP" ]
  then
    echo -e "${GREEN}Server is running with less than 2G of RAM without SWAP, creating 2G swap file.${NC}"
    SWAPFILE=$(mktemp)
    dd if=/dev/zero of=$SWAPFILE bs=1024 count=2M
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon -a $SWAPFILE
else
  echo -e "${GREEN}Server running with at least 2G of RAM, no swap needed.${NC}"
fi
clear
}

function compile_bitcoin_lightning() {
  echo -e "Clone git repo and compile it. This may take some time. Press a key to continue."
  read -n 1 -s -r -p ""

  cd $TMP_FOLDER
  git clone https://github.com/bitcoin-core/secp256k1
  cd secp256k1
  chmod +x ./autogen.sh
  ./autogen.sh
  ./configure
  make
  ./tests
  sudo make install 
  clear 

  cd $TMP_FOLDER
  git clone $BITCOIN_LIGHTNING_REPO
  cd Bitcoin-Lightning/src
  make -f makefile.unix 
  compile_error Bitcoin-Lightning
  cp -a Bitcoin-Lightningd /usr/local/bin
  cd ~
  rm -rf $TMP_FOLDER
  clear
}

function enable_firewall() {
  FWSTATUS=$(ufw status 2>/dev/null|awk '/^Status:/{print $NF}')
  if [ "$FWSTATUS" = "active" ]; then
    echo -e "Setting up firewall to allow ingress on port ${GREEN}$BITCOIN_LIGHTNINGPORT${NC}"
    ufw allow $BITCOIN_LIGHTNINGPORT/tcp comment "Bitcoin-Lightning MN port" >/dev/null
  fi
}

function systemd_Bitcoin-Lightning() {
  cat << EOF > /etc/systemd/system/$BITCOIN_LIGHTNINGUSER.service
[Unit]
Description=Bitcoin-Lightning service
After=network.target

[Service]
ExecStart=$BITCOIN_LIGHTNING_DAEMON -conf=$BITCOIN_LIGHTNINGFOLDER/$CONFIG_FILE -datadir=$BITCOIN_LIGHTNINGFOLDER
ExecStop=$BITCOIN_LIGHTNING_DAEMON -conf=$BITCOIN_LIGHTNINGFOLDER/$CONFIG_FILE -datadir=$BITCOIN_LIGHTNINGFOLDER stop
Restart=on-abort
User=$BITCOIN_LIGHTNINGUSER
Group=$BITCOIN_LIGHTNINGUSER

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $BITCOIN_LIGHTNINGUSER.service
  systemctl enable $BITCOIN_LIGHTNINGUSER.service

  if [[ -z "$(ps axo user:15,cmd:100 | egrep ^$BITCOIN_LIGHTNINGUSER | grep $BITCOIN_LIGHTNING_DAEMON)" ]]; then
    echo -e "${RED}Bitcoin-Lightningd is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $BITCOIN_LIGHTNINGUSER.service"
    echo -e "systemctl status $BITCOIN_LIGHTNINGUSER.service"
    echo -e "less /var/log/syslog${NC}"
  fi
}

function ask_port() {
read -p "BITCOIN_LIGHTNING Port: " -i $DEFAULTBITCOIN_LIGHTNINGPORT -e BITCOIN_LIGHTNINGPORT
: ${BITCOIN_LIGHTNINGPORT:=$DEFAULTBITCOIN_LIGHTNINGPORT}
}

function ask_user() {
  read -p "Bitcoin-Lightning user: " -i $DEFAULTBITCOIN_LIGHTNINGUSER -e BITCOIN_LIGHTNINGUSER
  : ${BITCOIN_LIGHTNINGUSER:=$DEFAULTBITCOIN_LIGHTNINGUSER}

  if [ -z "$(getent passwd $BITCOIN_LIGHTNINGMUSER)" ]; then
    USERPASS=$(pwgen -s 12 1)
    useradd -m $BITCOIN_LIGHTNINGUSER
    echo "$BITCOIN_LIGHTNINGUSER:$USERPASS" | chpasswd

    BITCOIN_LIGHTNINGHOME=$(sudo -H -u $BITCOIN_LIGHTNINGUSER bash -c 'echo $HOME')
    DEFAULTBITCOIN_LIGHTNINGFOLDER="$BITCOIN_LIGHTNINGHOME/.Bitcoin_Lightning"
    read -p "Configuration folder: " -i $DEFAULTBITCOIN_LIGHTNINGFOLDER -e BITCOIN_LIGHTNINGFOLDER
    : ${BITCOIN_LIGHTNINGFOLDER:=$DEFAULTBITCOIN_LIGHTNINGFOLDER}
    mkdir -p $BITCOIN_LIGHTNINGFOLDER
    chown -R $BITCOIN_LIGHTNINGUSER: $BITCOIN_LIGHTNINGFOLDER >/dev/null
  else
    clear
    echo -e "${RED}User exits. Please enter another username: ${NC}"
    ask_user
  fi
}

function check_port() {
  declare -a PORTS
  PORTS=($(netstat -tnlp | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
  ask_port

  while [[ ${PORTS[@]} =~ $BITCOIN_LIGHTNINGPORT ]] || [[ ${PORTS[@]} =~ $[BITCOIN_LIGHTNINGPORT+1] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function create_config() {
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  cat << EOF > $BITCOIN_LIGHTNINGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$[BITCOIN_LIGHTNINGPORT+1]
listen=1
server=1
daemon=1
addnode=188.166.54.195
addnode=128.199.33.244
port=$BITCOIN_LIGHTNINGPORT
EOF
}

function create_key() {
  echo -e "Enter your ${RED}Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
  read -e BITCOIN_LIGHTNINGKEY
  if [[ -z "$BITCOIN_LIGHTNINGKEY" ]]; then
  sudo -u $BITCOIN_LIGHTNINGUSER $BITCOIN_LIGHTNING_DAEMON -conf=$BITCOIN_LIGHTNINGFOLDER/$CONFIG_FILE -datadir=$BITCOIN_LIGHTNINGFOLDER
  sleep 5
  if [ -z "$(ps axo user:15,cmd:100 | egrep ^$BITCOIN_LIGHTNINGUSER | grep $BITCOIN_LIGHTNING_DAEMON)" ]; then
   echo -e "${RED}Bitcoin_Lightningd server couldn't start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  BITCOIN_LIGHTNINGKEY=$(sudo -u $BITCOIN_LIGHTNINGUSER $BITCOIN_LIGHTNING_DAEMON -conf=$BITCOIN_LIGHTNINGFOLDER/$CONFIG_FILE -datadir=$BITCOIN_LIGHTNINGFOLDER masternode genkey)
  sudo -u $BITCOIN_LIGHTNINGUSER $BITCOIN_LIGHTNING_DAEMON -conf=$BITCOIN_LIGHTNINGFOLDER/$CONFIG_FILE -datadir=$BITCOIN_LIGHTNINGFOLDER stop
fi
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $BITCOIN_LIGHTNINGFOLDER/$CONFIG_FILE
  cat << EOF >> $BITCOIN_LIGHTNINGFOLDER/$CONFIG_FILE
maxconnections=256
masternode=1
masternodeaddr=$NODEIP:$BITCOIN_LIGHTNINGPORT
masternodeprivkey=$BITCOIN_LIGHTNINGKEY
EOF
  chown -R $BITCOIN_LIGHTNINGUSER: $BITCOIN_LIGHTNINGFOLDER >/dev/null
}

function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "Bitcoin-Lightning Masternode is up and running as user ${GREEN}$BITCOIN_LIGHTNINGUSER${NC} and it is listening on port ${GREEN}$BITCOIN_LIGHTNINGPORT${NC}."
 echo -e "${GREEN}$BITCOIN_LIGHTNINGUSER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$BITCOIN_LIGHTNINGFOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $BITCOIN_LIGHTNINGUSER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $BITCOIN_LIGHTNINGUSER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODEIP:$BITCOIN_LIGHTNINGPORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$BITCOIN_LIGHTNINGKEY${NC}"
 echo -e "Please check Bitcoin-Lightning is running with the following command: ${GREEN}systemctl status $BITCOIN_LIGHTNINGUSER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
  ask_user
  check_port
  create_config
  create_key
  update_config
  enable_firewall
  important_information
  systemd_Bitcoin-Lightning
}


##### Main #####
clear

checks
if [[ ("$NEW_BITCOIN_LIGHTNING" == "y" || "$NEW_BITCOIN_LIGHTNING" == "Y") ]]; then
  setup_node
  exit 0
elif [[ "$NEW_BITCOIN_LIGHTNING" == "new" ]]; then
  prepare_system
  compile_Bitcoin-Lightning
  setup_node
else
  echo -e "${GREEN}Bitcoin_Lightningd already running.${NC}"
  exit 0
fi

