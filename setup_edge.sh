#!/usr/bin/env bash
set -e

function usage() {
  local just_help=$1
  local missing_required=$2
  local invalid_option=$3
  local invalid_argument=$4

  local help="Usage: sudo ./setup_edge.sh [OPTIONS]

Used to create a init.d script to startup and destroy an edge

Assumptions: 
/usr/local/bin/edge exists
TODO: Run it as a user, right now it runs as root.

Notes:
- Stores db in /var/lib/clearblade/
- Stores logs in /var/log/edge.log
- Stores Adapters in /var/lib/adapters
- Add/Del enable/disables the serivice using `chkconfig` command provided by `rhel 6.0`
- The init service uses `daemon` command


Attention: 
This setup script updates the existing service

Example: sudo ./setup_edge.sh --platform-ip 'platfrom.clearblade.com' --parent-system '8ecae4eb908das88b4feb3db14' --edge-ip 'localhost' --edge-id 'some-edge' --edge-cookie 'sd1474594aafefds4V42Ebt'

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
ALL_ARGS=("platform_ip" "parent_system" "edge_ip" "edge_id" "edge_cookie" )
REQ_ARGS=("platform_ip" "parent_system" "edge_ip" "edge_id" "edge_cookie" )

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

for i in "${REQ_ARGS[@]}"; do
  # $i is the string of the variable name
  # ${!i} is a parameter expression to get the value
  # of the variable whose name is i.
  req_var=${!i}
  if [ "$req_var" == "" ]
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

#----------FILESYSTEM SETTINGS FOR EDGE
BINPATH=/usr/local/bin
CBVARPATH=/var/lib/clearblade
EDGEDBDIR=$CBVARPATH/db
EDGEDBPATH=$EDGEDBDIR/edge.db
ADAPTERS_ROOT_DIR=$CBVARPATH
#---------Setup the edge-config file------
CONFIG_ROOT=/etc/clearblade
EDGE_CONFIG_FILE=$CONFIG_ROOT/config.toml
EDGE_LOG_FILE=/var/log/edge.log

#---------Log Edge Settings---------

#---------Check File system settings for edge----------
echo -e "\n----- $((++j)). edge file-sys settings check-----\n"
echo "BINPATH: $BINPATH"
echo "CBVARPATH: $CBVARPATH"
echo "EDGEDBDIR: $EDGEDBDIR"
echo "EDGEDBPATH: $EDGEDBPATH"
echo "ADAPTERS_ROOT_DIR: $ADAPTERS_ROOT_DIR"
echo "CONFIG_ROOT: $CONFIG_ROOT"
echo "EDGE_CONFIG_FILE: $EDGE_CONFIG_FILE"
echo "EDGE_LOG_FILE: $EDGE_LOG_FILE"

echo -e "\n----- $((++j)). Creating Directories if Missing-----\n"

mkdir -p $CONFIG_ROOT
mkdir -p $ADAPTERS_ROOT_DIR
mkdir -p $EDGEDBDIR

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
DBType = "sqlite"
SqliteAdmin = "$EDGEDBPATH" # (string) Location for storing sqlite admin database file
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

echo -e "\n----- $((++j)). Config Created Successfully, stored at location: $EDGE_CONFIG_FILE -----\n"