#!/bin/bash
## Assumptions
## 1. Needs 'curl' if downloading & installing the edge.
## 2. Assumes Edge Binary exists in '/usr/local/bin/' as 'edge'
## 3. If downloading and installing edge binary, perform step 6 (Uncomment)

#---------Edge Version---------------
RELEASE="4.3.3" 

#----------CONFIGURATION SETTINGS FOR EDGE
EDGECOOKIE=<EDGE_COOKIE> #Cookie from Edge Config Screen
EDGEID=<EDGE_ID> #Edge Name when Created in the system
PARENTSYSTEM=<PARENT_SYSTEM_KEY> #System Key of the application to connect
PLATFORMFQDN=<PLATFORM_URL> #FQDN Hostname to Connect

#----------FILESYSTEM SETTINGS FOR EDGE
BINPATH=/usr/local/bin
VARPATH=/var/lib
CBBINPATH=$BINPATH/clearblade
EDGEDBPATH=$VARPATH/clearblade
EDGEUSERDBNAME=edgeusers.db
EDGEDBNAME=edge.db
DISABLEPPROF=true


#---------Edge Settings---------
EDGEBIN="$BINPATH/clearblade/edge"
DATASTORE="-db=sqlite -sqlite-path=$EDGEDBPATH/$EDGEDBNAME -sqlite-path-users=$EDGEDBPATH/$EDGEUSERDBNAME" # or "-local"

#---------Logging Info---------
LOGLEVEL="info"

#---------Init.d Configuration---------
INITDPATH="/etc/init.d"
INITDDEFAULTPATH="/etc/default"
INITDSERVICENAME="clearblade"
SERVICENAME="ClearBlade Edge Service"


#######################################################
#---------Ensure your architecture is correct----------
#######################################################
MACHINE_ARCHITECTURE="$(uname -m)"
MACHINE_OS="$(uname)"
echo "Machine Architecture: $MACHINE_ARCHITECTURE"
if [ "$MACHINE_ARCHITECTURE" == "armv5tejl" ] ; then
  ARCHITECTURE="edge-linux-armv5tejl.tar.gz"
elif [ "$MACHINE_ARCHITECTURE" == "armv6l" ] ; then
  ARCHITECTURE="edge-linux-armv6.tar.gz"
elif [ "$MACHINE_ARCHITECTURE" == "armv7l" ] ; then
  ARCHITECTURE="edge-linux-armv7.tar.gz"
elif [ "$MACHINE_ARCHITECTURE" == "armv8" ] ; then
  ARCHITECTURE="edge-linux-arm64.tar.gz"
elif [ "$MACHINE_ARCHITECTURE" == "i686" ] ||  [ "$MACHINE_TYPE" == "i386" ] ; then
  ARCHITECTURE="edge-linux-386.tar.gz"
elif [ "$MACHINE_ARCHITECTURE" == "x86_64" ] && [ "$MACHINE_OS" == "Darwin" ] ; then
  ARCHITECTURE="edge-darwin-amd64.tar.gz" 
elif [ "$MACHINE_ARCHITECTURE" == "x86_64" ] && [ "$MACHINE_OS" == "Linux" ] ; then
  ARCHITECTURE="edge-linux-amd64.tar.gz"
else 
  echo "---------Unknown Architecture Error---------"
    echo "STOPPING: Validate Architecture of OS"
    echo "-----------------------------------"
  exit
fi


echo "--------------------1. Installing Prereqs Skipping..."
# apt-get install sudo -y
#---------Pre Reqs-------------------
# sudo apt-get update -y
# sudo apt-get install curl -y


echo ---------------------2. Edge Config
echo "EDGECOOKIE: $EDGECOOKIE"
echo "EDGEID: $EDGEID"
echo "PARENTSYSTEM: $PARENTSYSTEM"
echo "PLATFORMFQDN: $PLATFORMFQDN"
echo "EDGEBIN: $EDGEBIN"
echo "RELEASE: $RELEASE"
echo "DATASTORE: $DATASTORE"
echo "ARCHITECTURE: $ARCHITECTURE"
echo "LOGLEVEL: $LOGLEVEL"


echo ---------------------3. Init.d Config
echo "INITDPATH: $INITDPATH"
echo "INITDSERVICENAME: $INITDSERVICENAME"
echo "SERVICENAME: $SERVICENAME"


echo ---------------------4. Cleaning old init.d services and binaries
service $INITDSERVICENAME stop
update-rc.d -f $INITDSERVICENAME remove

rm $INITDPATH/$INITDSERVICENAME
rm "$EDGEBIN"


echo ---------------------5. Creating File Structure
mkdir $BINPATH #Just in case bin doesn't exist in /usr
mkdir $CBBINPATH
mkdir $EDGEDBPATH
chmod +w $EDGEDBPATH


#echo ---------------------6. Downloading and Installing Edge
#echo "https://github.com/ClearBlade/Edge/releases/download/$RELEASE/$ARCHITECTURE"
#curl -#SL -L "https://github.com/ClearBlade/Edge/releases/download/$RELEASE/$ARCHITECTURE" -o /tmp/$ARCHITECTURE

#tar xzvf /tmp/$ARCHITECTURE
#mv edge-$RELEASE $EDGEBIN
#chgrp root $EDGEBIN
#chown admin $EDGEBIN
#chmod +x "$EDGEBIN"

#rm /tmp/$ARCHITECTURE


echo ---------------------7. Creating clearblade edge init.d service

cat >$INITDSERVICENAME <<EOF
#!/bin/sh

set -e

### BEGIN INIT INFO
# Provides:           $INITDSERVICENAME
# Required-Start:     \$network \$local_fs \$syslog \$remote_fs \$named \$portmap
# Required-Stop:      \$network \$local_fs \$syslog \$remote_fs \$named \$portmap
# Default-Start:      2 3 4 5
# Default-Stop:       0 1 6
# Short-Description:  $SERVICENAME
### END INIT INFO

. /etc/default/edge
. /etc/init.d/functions

PATH=/usr/sbin:/usr/bin:/sbin:/bin


EDGE_FLAGS="-db=sqlite -novi-ip=\$CB_IP -edge-listen-port=\$EDGE_LISTEN_PORT -broker-tcp-port=\$BROKER_TCP_PORT \\
-broker-tls-port=\$BROKER_TLS_PORT -edge-ip=localhost -parent-system=\$SYSTEM_KEY -edge-ip=localhost -edge-id=\$EDGE_ID \\
-edge-cookie=\$EDGE_COOKIE -log-level=\$LOG_LEVEL -adaptors-root-dir=\$ADAPTER_DIRECTORY -sqlite-path=$EDGEDBPATH/$EDGEDBNAME \\
-sqlite-path-users=$EDGEDBPATH/$EDGEUSERDBNAME -store-analytics=false -store-message-history=true -store-logs=true"


start() {
    echo "Starting ClearBlade Edge..."

    start-stop-daemon --start --quiet --oknodo --background --pidfile \$EDGE_PIDFILE --make-pidfile \\
    --chdir /home/root --chuid root \\
    --startas /bin/bash -- -c "exec \$EDGE \$EDGE_FLAGS > \$EDGE_LOG 2>&1"
}

stop() {
    echo "Stopping ClearBlade Edge..."
    start-stop-daemon --stop --quiet --oknodo --pidfile \$EDGE_PIDFILE --retry 10
    rm -f \$PIDFILE
}


case "\$1" in
    start)
        start
        ;;

    stop)
        stop
        ;;

    restart)
        stop
        start
        ;;

    *)
        echo "Usage: \$0 {start|stop|restart}"
        exit 1
        ;;
esac

EOF

echo ---------------------7a. Placing $INITDSERVICENAME service in $INITDPATH directory
mv $INITDSERVICENAME $INITDPATH
chmod +x "$INITDPATH/$INITDSERVICENAME"

echo ---------------------7b. Creating $INITDSERVICENAME init.d defaults-------------
cat >$INITDSERVICENAME <<EOF
CB_IP=$PLATFORMFQDN
EDGE=$EDGEBIN
EDGE_COOKIE=$EDGECOOKIE
EDGE_ID=$EDGEID
EDGE_PIDFILE=/var/run/edge.pid
EDGE_LOG=/var/log/edge
SYSTEM_KEY=$PARENTSYSTEM
BROKER_TCP_PORT=2883
BROKER_TLS_PORT=2884
EDGE_LISTEN_PORT=:9001
LOG_LEVEL=info
ADAPTER_DIRECTORY=$VARPATH
EOF

echo ---------------------7c. Placing init.d defaults in $INITDDEFAULTPATH directory
mv $INITDSERVICENAME $INITDDEFAULTPATH


echo ---------------------8. Starting the $INITDSERVICENAME service
update-rc.d $INITDSERVICENAME defaults
service $INITDSERVICENAME start

echo ---------------------9. Waiting for Startup ---------------------
sleep 10 &

service $INITDSERVICENAME status
echo "Run ----'service $INITDSERVICENAME status '------for status"





