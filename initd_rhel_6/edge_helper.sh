


EDGEDBPATH=$VARPATH/db/edge.db
ADAPTERS_ROOT_DIR=$VARPATH

## Removing DB
[[ -z "$reset_db" ]] && rm -rf "$EDGEDBPATH"
