#!/bin/sh

# SUN reports
# Each perl script is run indiviudally.  Copy each report into a date stamped
# directory, and keep about a week's worth.
# 
# Reports a currently copied into
#
#   /var/data/xt_static/utilities/data_transfer/maxisun/am/csv
#
# But somewhere under xt_static may be better


DDATE=`date +%Y%m%d`
REPORT_DIR=/var/data/xt_static/utilities/data_transfer/maxisun/am/csv

/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/do.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/dg.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/dgc.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/sku.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/season.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/desemp.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/supplier.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/poso.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/so.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/sg.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/sgr.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/sge.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/store_credits.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/smd.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/smdr.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/rtv.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/mainstock.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/mainstock_audit.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/samplestock.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/am/samplestock_audit.pl

# keep a copy of reports somewhere

cd ${REPORT_DIR}
mkdir ${DDATE}
/bin/cp -p *.csv ${DDATE}/.

# delete the ones older than 1 week

#/usr/bin/find ${REPORT_DIR} -mtime +8 xargs -exec rm -f {} \;
