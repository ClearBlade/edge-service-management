#!/usr/bin/env bash

set -ex

function usage() {
  local just_help=$1
  local missing_required=$2
  local invalid_option=$3
  local invalid_argument=$4

  local help="Usage: ./create_edge_service.sh [OPTIONS]

Used to create a init.d script to startup and destroy an edge

Assumptions: 
/usr/local/bin/edge exists
TODO: Run it as a user, right now it runs as root.
TODO: Find out the best way to store the pid in the pidfile and thus be able to using the /etc/init.d/functions in a better way

Notes:
- Stores db in /var/lib/clearblade/
- Stores logs in /var/log/edge.log
- Stores Adapters in /var/lib/adapters
- Add/Del enable/disables the serivice using `chkconfig` command provided by `rhel 6.0`
- The init service uses `daemon` command
- Tested for: Linux version 2.6.32-754.27.1.el6.x86_64

Attention: 
This setup script wipes all the existing services|databases|adapters|

Example: `./create_edge_service.sh --display-name "ClearBlade Edge Service" --service-name "clearblade_edge" --config "/etc/clearblade/config.toml" --prog "/usr/local/bin/edge" --reset-db "true"`

Options (* indicates it is required):
      * --display-name string      Long description of the Service Name
      * --service-name string      service name in one_word
        --config string            path to config file, the setup file usually creates it; default: /etc/clearblade/config.toml
        --prog string              [absolute path to the binary] default: /usr/local/bin/edge
        --reset-db                 a flag, if you wish to reset the db
        --lib-folder string        path to root folder for db and adapters directory; default: /var/lib/clearblade
    -h, --help                     Displays this usage text.
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

ALL_ARGS=("service_display_name" "service_name" "config" "prog" "reset_db" "lib_folder" )
REQ_ARGS=("service_display_name" "service_name" )

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
    service_display_name="$2"
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
    --prog)
    bin_path="$2"
    shift 2
    ;;
    --lib-folder)
    lib_folder="$2"
    shift 2
    ;;
    --reset-db)
    reset_db="true"
    shift
    ;;
    *)
    usage "" "" "$1"
    shift
    ;;
esac
done

for i in "${REQ_ARGS[@]}"; do
  # $i is the string of the variable name
  # ${!i} is a parameter expression to get the value
  # of the variable whose name is i.
  req_var=${!i}
  if [ "$req_var" = "" ]
  then
    usage "" "--$i"
    exit
  fi
done

script_name="${0}"
j=0

echo -e "\n----- $script_name-----\n"
echo -e "\n----- $((++j)). inputs-check-----\n"

for i in "${ALL_ARGS[@]}"; do
  # $i is the string of the variable name
  # ${!i} is a parameter expression to get the value
  # of the variable whose name is i.
  var_val=${!i}
  echo "$i:\"$var_val\""
done

## Step counter
## $((++j))

#---------Init.d Configuration & edge defaults---------
INITDPATH="/etc/init.d"
INITDDEFAULTPATH="/etc/default"

EDGE_CONFIG_FILE=${config_file-"/etc/clearblade/config.toml"}
EDGE_BIN_PATH=${bin_path-"/usr/local/bin/edge"}

VARPATH=${lib_folder-"/var/lib/clearblade"}
EDGEDBPATH=$VARPATH/db/edge.db
ADAPTERS_ROOT_DIR=$VARPATH

#---------Check Init.d Configuration---------
echo -e "\n----- $((++j)). init.d config check------\n"
echo "INITDPATH: $INITDPATH"
echo "INITDDEFAULTPATH: $INITDDEFAULTPATH"
echo "EDGE_BIN_PATH: $EDGE_BIN_PATH"
echo "ADAPTERS_ROOT_DIR: $ADAPTERS_ROOT_DIR"

echo -e "\n----- $((++j)). clean old init.d services, binaries, adapters & databases-----\n"

service $service_name stop

## Removing DB & Service
[[ -z "$reset_db" ]] && rm -rf "$EDGEDBPATH"
rm -rf "$service_name" 

# update-rc.d -f $service_name remove
chkconfig $service_name off
chkconfig --del "$INITDPATH/$service_name"

rm "$INITDPATH/$service_name"

echo -e "\n----- $((++j)). Creating clearblade edge init.d service-----\n"

cat > "$service_name" <<EOF
#!/bin/sh

### BEGIN INIT INFO
# Provides:           $service_name
# Required-Start:     \$network \$local_fs \$syslog \$remote_fs \$named \$portmap
# Required-Stop:      \$network \$local_fs \$syslog \$remote_fs \$named \$portmap
# Default-Start:      2 3 4 5
# Default-Stop:       0 1 6
# Short-Description:  $service_display_name
### END INIT INFO


. $INITDDEFAULTPATH/$service_name
. /etc/init.d/functions


PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin


EDGE_FLAGS="-config=\$EDGE_CONFIG_FILE"

lockfile=/var/lock/subsys/$service_name

start() {
    echo -n "Starting $service_display_name: "
    daemon --pidfile=\$EDGE_PIDFILE \$EDGE -config=\$EDGE_CONFIG_FILE & 
    retval=\$?
    if [ \$retval -eq 0 ]; then
          touch \$lockfile
          echo "\n Started Successfully..."
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
    echo -n \$"Stopping $service_name"
    killproc \$exec
    retval=\$?
    [ \$retval -ne 0 ] && failure \$"Stopping $service_name"

    rm -f \$lockfile
    echo "\n Stopped Successfully..."
    return \$retval
}

status() {
  # see if running
  prog=\$(basename \$EDGE)
  local pids=\$(pgrep \$prog)

  if [ -n "\$pids" ]; then
    echo "\$prog (pid \$pids) is running"
  else
    echo "\n \$prog is stopped"
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



echo -e "\n----- $((++j)). Placing $service_name service in $INITDPATH directory-----\n"
mv $service_name $INITDPATH
chmod +x "$INITDPATH/$service_name"

echo -e "\n----- $((++j)). Creating $service_name init.d defaults, loaded at the time of service creation/execution-----\n"
cat >$service_name <<EOF
EDGE=$EDGE_BIN_PATH
EDGE_PIDFILE=/var/run/edge.pid
EDGE_CONFIG_FILE=$EDGE_CONFIG_FILE
EOF

echo -e "\n----- $((++j)). Placing init.d defaults in $INITDDEFAULTPATH directory-----\n"
mv $service_name $INITDDEFAULTPATH

chkconfig --add "$INITDPATH/$service_name"


echo -e "\n----- $((++j)). Starting the $service_name service-----\n"
# update-rc.d $service_name defaults
service $service_name stop
service $service_name start
chkconfig $service_name on


service $service_name status
echo "Run ----'service $service_name status '------for status"