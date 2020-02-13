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

## TODO add checks
ALL_ARGS=("platform-ip" "parent-system" "edge-ip" "edge-id" "edge-cookie")
REQ_ARGS=("platform-ip" "parent-system" "edge-ip" "edge-id" "edge-cookie")

# get command line arguments
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--help)
    usage 1
    exit
    ;;
    --platform-ip)
    platform_ip="$2"
    shift 2
    ;;
    --parent-system)
    parent_system="$2"
    shift 2
    ;;
    --edge-ip)
    edge_ip="$2"
    shift 2
    ;;
    --edge-id)
    edge_id="$2"
    shift 2
    ;;
    --edge-cookie)
    edge_cookie="$2"
    shift 2
    ;;
    *)
    usage "" "" "$1"
    shift
    ;;
esac
done

echo "-------------1. inputs-check-----------"
echo "platform_ip: $platform_ip"
echo "parent_system: $parent_system"
echo "edge_ip: $edge_ip"
echo "edge_id: $edge_id"
echo "edge_cookie: $edge_cookie"


#---------Init.d Configuration---------
INITDPATH="/etc/init.d"
INITDDEFAULTPATH="/etc/default"
INITDSERVICENAME="clearblade"
SERVICENAME="ClearBlade Edge Service"

#---------Check Init.d Configuration---------
echo "---------2. init.d config check---------"
echo "INITDPATH: $INITDPATH"
echo "INITDSERVICENAME: $INITDSERVICENAME"
echo "SERVICENAME: $SERVICENAME"

#----------FILESYSTEM SETTINGS FOR EDGE
BINPATH=/usr/local/bin
VARPATH=/var/lib
EDGEDBPATH=$VARPATH/clearblade
ADAPTERS_ROOT_DIR=$VARPATH

#---------Edge Settings---------
EDGEBIN="$BINPATH/edge"

#---------Check File system settings for edge----------
echo "-----------3. edge file-sys settings check-------"
echo "BINPATH: $BINPATH"
echo "VARPATH: $VARPATH"
echo "EDGEDBPATH: $EDGEDBPATH"
echo "ADAPTERS_ROOT_DIR: $ADAPTERS_ROOT_DIR"
echo "EDGEBIN: $EDGEBIN"

#---------Setup the edge-config file------
CONFIG_ROOT=/etc/clearblade
EDGE_CONFIG_FILE=$CONFIG_ROOT/config.toml
EDGE_LOG_FILE=/var/log/edge
#---------Check Setup for the edge-config file----------
echo "-----------Check Setup for the edge-config file-------"
echo "CONFIG_ROOT: $CONFIG_ROOT"
echo "EDGE_CONFIG_FILE: $EDGE_CONFIG_FILE"
echo "EDGE_LOG_FILE: $EGDE_LOG_FILE"
mkdir -p $CONFIG_ROOT

cat >$EDGE_CONFIG_FILE <<EOF
Title = "ClearBlade Edge Configuration File"

[Edge]
PlatformIP = "$platform_ip" # (string) the ip address or hostname of the platform without port or protocol (required)
PlatformPort = "8951" # (string) RPC port of the platform, default of 8951 for TLS
EdgeID = "$edge_id" # (string) Edge name (required)
EdgeCookie = "$edge_cookie" # (string) Edge Cookie/Token (required)
ParentSystemKey = "$parent_system" # (string) The parent system of the edge (required)
EdgeIP = "$edge_ip" # (string) The edge's IP. Defaults to localhost
EdgePrivateIP = "localhost" # (string) The edge's IP. Defaults to localhost
  [Adaptors]
  AdaptorsRootDir = "$ADAPTERS_ROOT_DIR" # (string) Directory where adaptor files are stored. Defaults to ./
  [Provisioning]
  ProvisioningMode = false # (boolean) Need to provison (point at a platform) before edge is functional (default: false)
  ProvisioningSystem = "" # (string) System key of the provisioning system (default: '')
  ProvisionalSqliteAdmin = "./prov_clearblade.db" # (string) Location of the provisioning sqlite admin db file
  ProvisionalSqliteUserdata = "./prov_clearblade_users.db" # (string) Location of the provisioning sqlite userdata db file


[HTTP]
HttpPort = ":9000" # (string) Listen port for the HTTP server

[MQTT]
BrokerTCPPort = "1883" # (string) Listen port for MQTT broker
BrokerTLSPort = ":1884" # (string) TLS listen port for MQTT broker
BrokerWSPort = ":8903" # (string) Websocket listen port for MQTT broker
BrokerWSSPort = ":8904" # (string) TLS websocket listen port for MQTT broker
MessagingAuthPort = ":8905" # (string) Listen port for MQTT Auth broker
MessagingAuthWSPort = ":8907" # (string) Websocket listen port for MQTT Auth broker

[Security]
ExpireTokens = true # (boolean) Set to invalidate user/device tokens issued more than the system's tokenTTL (defaults to 5 days). Dev tokens will not be removed
InsecureAuth = false # (boolean) Disables password hashing if set to true. Used only for development
Insecure = false # (boolean) Disables edge to platform TLS communication if set to true. Used only for development

[Logging]
Logfile = "$EDGE_LOG_FILE" # (string) Location of logfile. If the value "stderr" or "stdout" are supplied, then it will forward to their respective file handles
MaxLogFileSizeInKB = -1 # (int64) Maximum size of log file before rotation in KB. Must be greater than 100 KB. -1 indicates no limit
MaxLogFileBackups = 1 # (int) Maximum backups of the log file. Must be greater than 1
LogLevel = "info" # (string) Raise minimum log-level (debug,info,warn,error,fatal)

[Database]
DBStore = "sqlite" # (string) Database store to use. postgres for platform and sqlite for edge
DBHost = "127.0.0.1" # (string) Address of the database server
DBPort = "5432" # (string) Database port
DBUsername = "cbuser" # (string) Username for connecting to the database
DBPassword = "ClearBlade2014" # (string) Password for connecting to the database
SqliteAdmin = "$EDGEDBPATH/edge.db" # (string) Location for storing sqlite admin database file
SqliteUserdata = "$EDGEDBPATH/edgeusers.db" # (string) Location for storing sqlite admin database file
Local = false # (boolean) Use only local cache for storage. Used only for development

[Debug]
DevelopmentMode = false # (boolean) Enables debug messages and triggers. Used only for development
DisablePprof = true # (boolean) This will disable pprof output file creation and pprof web-server creation if set to true
PprofCPUInterval = 10 # (int) The length of time, in minutes, to wait between successive pprof cpu profile generations
PprofHeapInterval = 10 # (int) The length of time, in minutes, to wait between successive pprof heap profile generations
PprofMaxFiles = 30 # (int) The maximum number of cpu and heap profiles to retain. 0 indicates keep all of them
PprofMaxFileAge = 1440 # (int) The maximum amount of time, specified in minutes, in which to retain cpu and heap profile data files
DumpRoutes = false # (boolean) Dump the routes being served for diagnostic purposes

[LeanMode]
LeanMode = false # (boolean) Stop storing analytics, message history and code logs if set to true
StoreAnalytics = true # (boolean) Stop storing analytics if set to false
StoreMessageHistory = true # (boolean) Stop storing message history if set to false
StoreCodeLogs = true # (boolean) Stop storing code logs if set to false
MaxCodeLogs = 25 # (int) Maximum number of most recent code logs to keep (Default: 25)
MaxAuditTrailDays = 7 # (int) Number of days of audit trail to keep

[RPC]
RPCTransport = "tcp" # (string) Transport layer for RPC communications
RPCPort = "8950" # (string) Listen port for external RPC server. Used to edge to platform communication
RPCTimeout = 120 # (int) Timeout for all RPC calls either within the platform or from platform to edge
RPCKeepaliveInterval = 60 # (int) Keepalive interval for RPC connections

[Sync]
SyncTransport = "mqtt" # (string) (Deprecated)
E2PInsertOnDeploy = true # (boolean) Disables or enables e2p insert behaviour when only deploy is set in a deployment
SyncOptimize = false # (boolean) Optimizes the syncing process if set to true
SyncOptimizeExceptions = "" # (string) Exceptions for the sync optimization process
SyncOptimizations = "" # (string) List specific optimizations to run. Default is all
SyncDistributeWaitTime = 1 # (int) How long to wait before distributing asset sync events

[MessageHistory]
DeletionEnabled = true # (boolean) Sets the default setting for message history autodeletion for new systems
ExpirationAgeSeconds = 1209600 # (int64) Sets the default setting for new systems for age at which a message should be deleted
MaxRowCount = 10000 # (int) Sets the default setting for new systems for maximum rows after message history deletion
MaxSizeKb = 15000 # (int) Sets the default setting for message history maximum size for new systems
TimePeriodDeleteMsgHistory = 120 # (int) Set the time interval to periodically erase msgHistory and analytics{Time.seconds}

[Triage]
PerformTriage = true # (bool) Turns triaging on and off (default on)
PerformMonitoring = false # (bool) turn on/off grafana monitoring (default off on edge)
MonitoringInterval = 5 # (int) interval between monitoring samples
PerformStackTriage = false # (bool) turn on/off stack triaging (default off on edge)
TriageDays = 1 # (int) Number of days to keep triage information in the database
TriageIntervalMinutes = 1  # (int) How often in minutes to report triage information
EnableLogFileWriter = false # (bool) turn on/off writing triage messages to log file (default off)

EOF

echo -------clean old init.d services, binaries, adapters & databases------
service $INITDSERVICENAME stop
# update-rc.d -f $INITDSERVICENAME remove
chkconfig $INITDSERVICENAME off
chkconfig --del "$INITDPATH/$INITDSERVICENAME"

rm "$INITDPATH/$INITDSERVICENAME"
#rm "$EDGEBIN"
rm "$ADAPTERS_ROOT_DIR/adapters"
rm "$EDGEDBPATH"


echo --------Creating File Structure-----
mkdir $BINPATH #Just in case bin doesn't exist in /usr
mkdir $EDGEDBPATH
chmod +w $EDGEDBPATH

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