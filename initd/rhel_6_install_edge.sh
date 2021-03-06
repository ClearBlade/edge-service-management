#!/usr/bin/env bash

function usage() {
  local just_help=$1
  local missing_required=$2
  local invalid_option=$3
  local invalid_argument=$4

  local help="Usage: sudo ./rhel_6_install_edge.sh [OPTIONS]

Used to create a init.d script to startup and destroy an edge

Assumptions: 
/usr/local/bin/edge exists
TODO: Run it as a user, right now it runs as root.
TODO: Find out the best way to store the pid in the pidfile and thus be able to using the /etc/init.d/functions in a better way

Notes:
- Stores db in /var/lib/clearblade/
- Stores logs in /var/log/edge
- Stores Adapters in /var/lib/adapters
- Add/Del enable/disables the serivice using `chkconfig` command provided by `rhel 6.0`
- The init service uses `daemon` command


Attention: 
This setup script wipes all the existing services|databases|adapters|

Example: sudo ./rhel_6_install_edge.sh --platform-ip 'cn.clearblade.com' --parent-system '8ecae4e30b908das88b4feb3db14' --edge-ip 'localhost' --edge-id 'some-edge' --edge-cookie 'sd1474594aafeffads4V42Ebt'

Options (* indicates it is required):
        --platform-ip string       [ENTER YOUR DESCRIPTION HERE]
        --parent-system string     [ENTER YOUR DESCRIPTION HERE]
        --edge-ip string           [ENTER YOUR DESCRIPTION HERE]
        --edge-id string           [ENTER YOUR DESCRIPTION HERE]
        --edge-cookie string       [ENTER YOUR DESCRIPTION HERE]
    -h, --help                      Displays this usage text.
"

  if [ "$just_help" != "" ]
  then
    echo "$help"
    return
  fi

  if [ "$missing_required" != "" ]
  then
    echo "Missing required argument: $missing_required"
  fi

  if [ "$invalid_option" != "" ] && [ "$invalid_value" = "" ]
  then
    echo "Invalid option: $invalid_option"
    return
  elif [ "$invalid_value" != "" ]
  then
    echo "Invalid value: $invalid_value for option: --$invalid_option"
  fi

  echo -e "\n"
  echo "$help"
  return
}


# get command line arguments
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--help)
    usage 1
    exit
    ;;
    --display-name)
    display_name="$2"
    shift 2
    ;;
    --service-name)
    service_name="$2"
    shift 2
    ;;
    --config)
    config_file="$2"
    shift 2
    ;;
    --reset-db)
    reset_db="$2"
    shift 2
    ;;
    *)
    usage "" "" "$1"
    shift
    ;;
esac
done



#---------Init.d Configuration---------
INITDPATH="/etc/init.d"
INITDDEFAULTPATH="/etc/default"
INITDSERVICENAME=$service_name
SERVICENAME=$display_name
EDGE_CONFIG_FILE=${config_file-"/etc/clearblade/config.toml"}


#--------Edge Paths----
VARPATH=/var/lib
EDGEDBPATH=$VARPATH/clearblade
ADAPTERS_ROOT_DIR=$VARPATH

#---------Check Init.d Configuration---------
echo "---------2. init.d config check---------"
echo "INITDPATH: $INITDPATH"
echo "INITDSERVICENAME: $INITDSERVICENAME"
echo "SERVICENAME: $SERVICENAME"

echo -------clean old init.d services, binaries, adapters & databases------
service $INITDSERVICENAME stop

## Removing DB & Service
rm -rf "$EDGEDBPATH" 
rm -rf "$INITDSERVICENAME" 

# update-rc.d -f $INITDSERVICENAME remove
chkconfig $INITDSERVICENAME off
chkconfig --del "$INITDPATH/$INITDSERVICENAME"

rm "$INITDPATH/$INITDSERVICENAME"

echo ---------------------7. Creating clearblade edge init.d service

cat >$INITDSERVICENAME <<EOF
#!/bin/sh

### BEGIN INIT INFO
# Provides:           $INITDSERVICENAME
# Required-Start:     \$network \$local_fs \$syslog \$remote_fs \$named \$portmap
# Required-Stop:      \$network \$local_fs \$syslog \$remote_fs \$named \$portmap
# Default-Start:      2 3 4 5
# Default-Stop:       0 1 6
# Short-Description:  $SERVICENAME
### END INIT INFO


. /etc/default/clearblade
. /etc/init.d/functions


PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin


EDGE_FLAGS="-config=\$EDGE_CONFIG_FILE"

lockfile=/var/lock/subsys/$INITDSERVICENAME

start() {
    echo -n "Starting $SERVICENAME: "
    daemon --pidfile=\$EDGE_PIDFILE \$EDGE -config=\$EDGE_CONFIG_FILE & 
    retval=\$?
    if [ \$retval -eq 0 ]; then
          touch \$lockfile
          echo "Started Successfully..."
    fi
    return \$retval
}

exec=\$EDGE

stop() {
    echo "Stopping the ClearBlade Edge..."
    if [ \$UID -ne 0 ] ; then
        echo "User has insufficient privilege."
        exit 4
    fi
    echo -n \$"Stopping $INITDSERVICENAME: "
    killproc \$exec
    retval=\$?
    [ \$retval -ne 0 ] && failure \$"Stopping $INITDSERVICENAME"

    rm -f \$lockfile
    echo "Stopped Successfully..."
    return \$retval
}

status() {
  # see if running
  prog=\$(basename \$EDGE)
  local pids=\$(pgrep \$prog)

  if [ -n "\$pids" ]; then
    echo "\$prog (pid \$pids) is running"
  else
    echo "\$prog is stopped"
  fi
  return 0
}


case "\$1" in
    start)
        start
        ;;

    stop)
        stop
        ;;
    status)
        status
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
EDGE=$EDGEBIN
EDGE_PIDFILE=/var/run/edge.pid
EDGE_CONFIG_FILE=$EDGE_CONFIG_FILE
EDGE_LOG=/var/log/edge_service.log
EOF

echo ---------------------7b. Placing init.d defaults in $INITDDEFAULTPATH directory
mv $INITDSERVICENAME $INITDDEFAULTPATH

chkconfig --add "$INITDPATH/$INITDSERVICENAME"


echo ---------------------8. Starting the $INITDSERVICENAME service
# update-rc.d $INITDSERVICENAME defaults
service $INITDSERVICENAME stop
service $INITDSERVICENAME start
chkconfig $INITDSERVICENAME on

echo ---------------------9. Waiting for Startup ---------------------
sleep 10 &

service $INITDSERVICENAME status
echo "Run ----'service $INITDSERVICENAME status '------for status"