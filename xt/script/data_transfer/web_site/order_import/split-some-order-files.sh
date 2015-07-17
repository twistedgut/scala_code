#!/bin/bash
#
# Parallel Order Importer
#
# Given the names of a few files in /var/data/xml/xmlwaiting,
# split those files up into individual order files.
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

SPLIT_ORDERS="$SCRIPT_DIR"/data_transfer/web_site/order_import/split-orders.pl

[ $# -ge 2 ] || { die 2 "Must provide an input directory and at least one file"; }

INPUT_DIR=$1

shift

[ -d "$INPUT_DIR" ] || { die 2 "XML input directory '$INPUT_DIR' cannot be found"; }

cd "$INPUT_DIR" 2>/dev/null || { die 2 "Cannot cd to XML input directory '$INPUT_DIR'"; }

TODAY=$(date '+%Y%m%d')

DATED_XMLPARALLELIZED_DIR="$XMLPARALLELIZED_DIR/$TODAY"
DATED_XMLPARALLEL_FAILED_DIR="$XMLPARALLEL_FAILED_DIR/$TODAY"

maybe_mkdir "$DATED_XMLPARALLELIZED_DIR"

for xmlfile
do
    if [ -f "$xmlfile" ]
    then
        if stabilize_file "$xmlfile"
        then
            if "$SPLIT_ORDERS" "$xmlfile" 2>/dev/null
            then
                mv "$xmlfile" "$DATED_XMLPARALLELIZED_DIR" ||
                    die 1 "Cannot move '$xmlfile' to '$DATED_XMLPARALLELIZED_DIR'"
            else
                maybe_mkdir "$DATED_XMLPARALLEL_FAILED_DIR"

                mv "$xmlfile" "$DATED_XMLPARALLEL_FAILED_DIR" ||
                    die 1 "Cannot move '$xmlfile' to '$DATED_XMLPARALLEL_FAILED_DIR'"
            fi
        fi
    fi &
done

wait

# not ideal, as we don't accurately report back if one of our children failed
#
# but that ought to be being logged anyway

exit 0
