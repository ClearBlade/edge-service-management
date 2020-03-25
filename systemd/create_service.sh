#!/bin/bash


function usage() {
  local just_help=$1
  local missing_required=$2
  local invalid_option=$3
  local invalid_argument=$4

  local help="Usage: ./create_service.sh [OPTIONS]

Used to create a ssystemd script to startup and destroy a binary

Assumptions: 

TODO: Run it as a user, right now it runs as root.

Notes:

OS supporting systemd as of March 25, 2020
Fedora 
RHEL 7 & later(mostly)
CentOS 7 & later(mostly)
Ubuntu 15.04 & later(mostly)
Debian 7 and Debian 8 and later(mostly)


Example: `./create_service.sh --display-name "ClearBlade Edge Service" --service-name "clearblade_edge" --params "-config=/etc/clearblade/config.toml" --prog "/usr/local/bin/edge"`

Options (* indicates it is required):
      * --display-name string      Long description of the Service Name
      * --service-name string      service name in one_word
        --params string            all params which maybe passed to the program
      * --prog string              [absolute path to the binary]
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

ALL_ARGS=("service_display_name" "service_name" "params" "bin_path" )
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
SYSTEMD_PATH="/lib/systemd/system"

echo -e "\n----- $((++j)). Configuration Check-----\n"
echo "Systemd Path: $SYSTEMD_PATH"
echo "Systemd Service Name: $service_name"
echo "Systemd Service Description: $service_display_name"

echo -e "\n----- $((++j)). Cleaning old systemd services and binaries-----\n"
sudo systemctl stop "$service_name"
sudo systemctl disable "$service_name"
sudo rm "$SYSTEMD_PATH/$service_name"
sudo rm -rf "$service_name"

echo -e "\n----- $((++j)). Creating clearblade service-----"

sudo cat >$service_name <<EOF
[Unit]
Description=$service_display_name
After=network.target
[Service]
Type=simple
User=root
ExecStart=$bin_path $params
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
sudo systemctl daemon-reload
sudo systemctl enable "$service_name"

echo -e "\n----- $((++j)). Starting the service-----\n"
sudo systemctl start "$service_name"

echo -e "\n----- $((++j)). Use  'sudo systemctl status $service_name' for status-----\n"
sudo systemctl status $service_name