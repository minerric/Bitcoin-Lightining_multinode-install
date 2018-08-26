# Bitcoin-Lightining_multinode-install

Install several Masternodes on 1 server with this Script
Just keep running it after it finishes and adding new user to the new Masternode


Bitcoin-Lightning
Shell script to install a Bitcoin-Lightning Masternode on a Linux server running Ubuntu 16.04. Use it on your own risk.

Installation:

wget -q https://raw.githubusercontent.com/minerric/Bitcoin-Lightining_multinode-install/master/Install.sh

bash Install.sh

Desktop wallet setup
After the MN is up and running, you need to configure the desktop wallet accordingly. Here are the steps:

Open the Bitcoin-Lightning Desktop Wallet.
Go to RECEIVE and create a New Address: MN1
Send 3000 BLTG to MN1.
Wait for 15 confirmations.
Go to Help -> "Debug window - Console"
Type the following command: masternode outputs
Go to Masternodes tab
Click Create and fill the details:
Alias: MN1
Address: VPS_IP:PORT
Privkey: Masternode Private Key
TxHash: First value from Step 6
Output index: Second value from Step 6
Reward address: leave blank
Reward %: leave blank
Click OK to add the masternode
Click Start All
Multiple MN on one VPS:
It is possible to run multiple Bitcoin-Lightning Master Nodes on the same VPS. Each MN will run under a different user you will choose during installation.

Usage:
For security reasons Bitcoin-Lightning is installed under Bitcoin-Lightning user, hence you need to su - Bitcoin-Lightning before checking:

BLTG_USER=Bitcoin-Lightning #replace Bitcoin-Lightning with the MN username you want to check

su - $BLTG_USER
Bitcoin_Lightningd masternode status
Bitcoin_Lightningd getinfo
Also, if you want to check/start/stop Bitcoin_Lightningd , run one of the following commands as root:

BLTG_USER=Bitcoin-Lightning  #replace Bitcoin-Lightning with the MN username you want to check  
  
systemctl status $BLTG_USER #To check the service is running.  
systemctl start $BLTG_USER #To start Bitcoin_Lightningd service.  
systemctl stop $BLTG_USER #To stop Bitcoin_Lightningd service.  
systemctl is-enabled $BLTG_USER #To check whetether Bitcoin_Lightningd service is enabled on boot or not.  

Any donation is highly appreciated

BLTG = B7HZ3gkt2dSgnwpooZJM7QhNC8Zfup47Dv
