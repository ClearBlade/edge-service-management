# Service Management Scripts for ClearBlade Edge Platform

## Warning
In pre-release phase, significant changes may occur

## Assumptions

Mentioned at the beginning of the scripts

## Setup
The setup step creates the config file in `/etc/clearblade/`

`sudo ./setup_edge.sh --platform-ip 'platform.clearblade.com' --parent-system '8ecae4eb908das88b4feb3db14' --edge-ip 'localhost' --edge-id 'some-edge' --edge-cookie 'sd1474594aafefds4V42Ebt'`


## Startup command

### Initd for RHEL 6

`sudo ./initd_rhel_6/create_edge_service.sh --display-name "ClearBlade Edge Service" --service-name "clearblade_edge" --config "/etc/clearblade/config.toml" --prog "$(pwd)/edge" --reset-db"`
