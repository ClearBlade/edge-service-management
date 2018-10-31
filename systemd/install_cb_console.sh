#!/bin/bash
## Assumptions:
## 1. Public folder exists in /srv/clearblade/www/
## 2  Assumes Console Binary exists in '/usr/local/bin/' as 'cb_console'
## 3. If Console binary exists in $CBCONSOLE_BASE_DIR/cb_console-$VERSION ex: /home/pi/cb_console-linux-armv7-4.1.5 ;
##    Perform Step 6
## 4. IP_ADDR for edge is localhost
## 
echo "Setting Configurations..."

## IP Address currently set to localhost, can use device's ip-address (given it has only one)
IP_ADDR="127.0.0.1"  #"$(/bin/hostname -I)"

#---------Console Configuration---------
CONSOLE_BIN="/usr/local/bin/cb_console"
RELEASE="linux-armv7-4.1.5"
CBCONSOLE_BASE_DIR="/home/pi"
CONSOLE_ASSETS="/srv/clearblade/www"
#---------Systemd Configuration---------
SYSTEMD_PATH="/lib/systemd/system"
SYSTEMD_SERVICE_NAME="cb_console.service"
SERVICE_NAME="ClearBlade Console Service"

#---------Edge Details------------
EDGE_PORT="9000"
EDGE_URL="http://${IP_ADDR}" #Hostname to Connect

echo "----------Configuration Check------------"
echo "IP Address: $IP_ADDR"
echo "Console Bin: $CONSOLE_BIN"
echo "Console Release: $RELEASE"
echo "Extracted Binary's Parent Dir: $CBCONSOLE_BASE_DIR"
echo "Location of Console's Public Folder: $CONSOLE_ASSETS"
echo "Systemd Path: $SYSTEMD_PATH"
echo "Systemd Service Name: $SYSTEMD_SERVICE_NAME"
echo "Systemd Service Description: $SERVICE_NAME"
echo "Edge Port: $EDGE_PORT"
echo "Edge Url: $EDGE_URL"

echo "1. Installing Prereqs Skipping..."
# apt-get install sudo -y
#---------Pre Reqs-------------------
# sudo apt-get update -y

echo "2. Cleaning old systemd services and binaries..."
sudo systemctl stop "$SYSTEMD_SERVICE_NAME"
sudo systemctl disable "$SYSTEMD_SERVICE_NAME"
sudo rm "$SYSTEMD_PATH/$SYSTEMD_SERVICE_NAME"
sudo rm -rf "$SYSTEMD_SERVICE_NAME"

echo "3. Installing Console Bin, if a fresh download, currently skipping..."
#sudo rm "$CONSOLE_BIN"
#sudo ln -f "$CBCONSOLE_BASE_DIR/cb_console-$RELEASE" "$CONSOLE_BIN"
#echo "Linking Successfull $?"
#sudo chmod +x "$CONSOLE_BIN"

echo "4. Creating ClearBlade Console service"

sudo cat >$SYSTEMD_SERVICE_NAME <<EOF
[Unit]
Description=$SERVICE_NAME Version: $RELEASE
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=$CONSOLE_ASSETS
ExecStart=$CONSOLE_BIN -platformURL=${EDGE_URL} -platformPort=${EDGE_PORT} -messageURL=${IP_ADDR}
Restart=on-abort
TimeoutSec=30
RestartSec=30
StartLimitInterval=350
StartLimitBurst=10

[Install]
WantedBy=multi-user.target

EOF

echo "5. Placing service in systemd folder..."

sudo mv "$SYSTEMD_SERVICE_NAME" "$SYSTEMD_PATH"

echo "6. Setting Startup Options"
## systemd reload so that it no longer attempts to reference old versions.
sudo systemctl daemon-reload
sudo systemctl enable "$SYSTEMD_SERVICE_NAME"

echo "7. Starting Service..."
sudo systemctl start "$SYSTEMD_SERVICE_NAME"
echo "Using  'sudo journalctl -u cb_console.service -n 50' for status"
sudo journalctl -u cb_console.service -n 50