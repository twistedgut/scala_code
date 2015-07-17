#!/bin/sh -
#
# Discover all the available ready order files, and import them in priority order
#

[ -n "$SCRIPT_DIR" ] || {
    echo "$0: invoke via the wrapper script to get an XT environment" >&2
    exit 2
}

. "$SCRIPT_DIR"/common-setup.sh

IMPORT_SOME_ORDERS="$SCRIPT_DIR"/data_transfer/web_site/order_import/import-some-orders.pl

[ -d "$XMPARALLEL_DIR" ] || die 1 "Directory '$XMPARALLEL_DIR' is missing"

( cd "$XMPARALLEL_DIR"
  ready_dirs=$(find * -type d -name "$READY_NAME")

  [ -n "$ready_dirs" ] && find $ready_dirs -type f -name \*.xml
) 2>/dev/null |
    sort -n   |
    head -n "${MAX_ORDERS_WITHOUT_PAUSING:-100}" |
    xargs -P "$MAX_CONCURRENT_IMPORTERS" \
          -n "$MAX_ORDERS_PER_IMPORTER"  \
          --no-run-if-empty              \
          "$IMPORT_SOME_ORDERS"
