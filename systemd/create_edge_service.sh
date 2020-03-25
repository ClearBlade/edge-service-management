#!/bin/bash


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
- Tested for: 

Attention: 
This setup script wipes all the existing services|databases|adapters|

Example: `./create_edge_service.sh --display-name "ClearBlade Edge Service" --service-name "clearblade_edge" --params "-config=/etc/clearblade/config.toml" --prog "/usr/local/bin/edge" --reset-db`

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

ALL_ARGS=("service_display_name" "service_name" "params" "prog" "reset_db" "lib_folder" )
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
    --params)
    params="$2"
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

echo -e "\n----- $((++j)). Setting Configurations-----\n"
#---------Edge Version---------
EDGE_CONFIG_FILE=${config_file-"/etc/clearblade/config.toml"}
BIN_PATH=${bin_path-"/usr/local/bin/edge"}
#service_name="clearblade.service"
#service_display_name="ClearBlade Edge Service"
default_log_file="/var/log/edge.log"

VARPATH=${lib_folder-"/var/lib/clearblade"}
EDGEDBPATH=$VARPATH/db/edge.db
ADAPTERS_ROOT_DIR=$VARPATH
#---------Systemd Configuration---------
SYSTEMD_PATH="/lib/systemd/system"
RELEASE=""
PARAMS=${params-"-config=$EDGE_CONFIG_FILE"}

echo -e "\n----- $((++j)). Configuration Check-----\n"
echo "Systemd Path: $SYSTEMD_PATH"
echo "Systemd Service Name: $service_name"
echo "Systemd Service Description: $service_display_name"

echo -e "\n----- $((++j)). Cleaning old systemd services and binaries-----\n"
sudo systemctl stop "$service_name"
sudo systemctl disable "$service_name"
sudo rm "$SYSTEMD_PATH/$service_name"
sudo rm -rf "$service_name"

[[ -z "$reset_db" ]] && rm -rf "$EDGEDBPATH"

echo -e "\n----- $((++j)). Creating clearblade service-----"

sudo cat >$service_name <<EOF
[Unit]
Description=$service_display_name Version: $RELEASE
After=network.target
[Service]
Type=simple
User=root
ExecStart=$BIN_PATH $PARAMS
Restart=always
TimeoutSec=30
RestartSec=30
StartLimitInterval=350
StartLimitBurst=10

[Install]
WantedBy=multi-user.target

EOF

echo -e "\n----- $((++j)). Placing service in systemd folder-----\n"

sudo mv "$service_name" "$SYSTEMD_PATH"

echo -e "\n----- $((++j)). Setting Startup Options-----\n"
# systemd reload so that it no longer attempts to reference old versions.
sudo systemctl daemon-reload
sudo systemctl enable "$service_name"

echo -e "\n----- $((++j)). Starting the service-----\n"
sudo systemctl start "$service_name"
echo -e "\n----- $((++j)). Use  'sudo systemctl status $service_name' for status; Default log file: $default_log_file -----\n"
sudo systemctl status $service_name