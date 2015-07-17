#!/bin/sh

# SUN reports
# Each perl script is run indiviudally.  Copy each report into a date stamped
# directory, and keep about a week's worth.
# 
# Reports a currently copied into
#
#   /var/data/xt_static/data/maxisun/intl/...
#
# But somewhere under xt_static may be better

if [ "$#" -lt "2" ]
then
    echo "usage: $0 <output dir> <channel_id>"
    exit 1
fi

DDATE=`date +%Y%m%d`
SCRIPT_DIR=/opt/xt/deploy/xtracker/script/data_transfer/maxisun/outnet
REPORT_DIR=/var/data/xt_static/data/maxisun/$1

echo "Generating Reference Files..."
${SCRIPT_DIR}/sku.pl --outdir=$1
${SCRIPT_DIR}/season.pl --outdir=$1
${SCRIPT_DIR}/desemp.pl --outdir=$1
${SCRIPT_DIR}/supplier.pl --outdir=$1
${SCRIPT_DIR}/poso.pl --outdir=$1 --channel_id=$2

echo "Generating Transaction Files..."
${SCRIPT_DIR}/do.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/dg.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/dgc.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/so.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/sg.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/sgr.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/sge.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/smd.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/smdr.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/rtv.pl --outdir=$1 --channel_id=$2

echo "Generating Static Files..."
${SCRIPT_DIR}/manual/mainstock.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/manual/mainstock_audit.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/manual/samplestock.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/manual/samplestock_audit.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/manual/maintosample.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/manual/sampletomain.pl --outdir=$1 --channel_id=$2
${SCRIPT_DIR}/manual/store_credits.pl --outdir=$1 --channel_id=$2


# keep a copy of reports somewhere

cd ${REPORT_DIR}
mkdir ${DDATE}
/bin/cp -p *.csv ${DDATE}/.
