#!/bin/bash
#
# Parallel Order Importer
#
# Run multiple instances of the order importer, each with a small amount of work
# doled out to it, to better use the available CPU resources on a box that has them,
# while also preventing Order Importer processes from running for too long individually
#
# So, here's what we do:
#
# We grab the order files that are dropped off into /var/data/xml/xmlwaiting
#
# We separate them by shipping priority and channel into subdirectories such as:
#
#  /var/data/xmparallel/10-PREMIER/ready/1-NAP-order-1234567-001.xml
#  /var/data/xmparallel/20-EXPRESS/ready/2-MRP-order-...
#  /var/data/xmparallel/40-STANDARD/ready/7-JCHOO...
#  /var/data/xmparallel/99-STAFF/ready/5-OUT....
#
# In each of those, there will be incoming, ready, succeeded and failed subdirectories
#
# Independently, there is expected to be an independent cron job per
# priority/channel stream, which will pick up the inbound files and
# process them in chunks.
#

[ -n "$SCRIPT_DIR" ] || {
    echo "$0: invoke via the wrapper script to get an XT environment" >&2
    exit 2
}

. "$SCRIPT_DIR"/common-setup.sh

ORDER_IMPORT_SCRIPT_DIR="$SCRIPT_DIR"/data_transfer/web_site/order_import

      LIST_ORDER_FILES="$ORDER_IMPORT_SCRIPT_DIR"/list-order-files.pl
SPLIT_SOME_ORDER_FILES="$ORDER_IMPORT_SCRIPT_DIR"/split-some-order-files.pl

[ -d "$XMLWAITING_DIR" ] || die 1 "Directory '$XMLWAITING_DIR' is missing"

# don't use anything that attempts to expand $XMLWAITING_DIR/*xml
# since that can blow the bash line-length limit when there are many
# files to process, and that would break the script

"$LIST_ORDER_FILES" "$XMLWAITING_DIR" |
    xargs -P "$MAX_CONCURRENT_SPLITTERS" \
          -n "$MAX_FILES_PER_SPLITTER"  \
          --no-run-if-empty              \
          "$SPLIT_SOME_ORDER_FILES" "$XMLWAITING_DIR"

exit 0
