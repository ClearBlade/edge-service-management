# Service Management Scripts for ClearBlade Edge Platform

## Warning
In pre-release phase, significant changes may occur

## Assumptions

Mentioned at the beginning of the scripts

## Startup command

### Initd for RHEL 6

`sudo ./initd_rhel_6/create_edge_service.sh --display-name "ClearBlade Edge Service" --service-name "clearblade_edge" --config "/etc/clearblade/config.toml" --prog "$(pwd)/edge" --reset-db"`
