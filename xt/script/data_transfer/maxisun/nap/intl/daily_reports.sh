#!/bin/sh

# SUN reports
# Each perl script is run indiviudally.  Copy each report into a date stamped
# directory, and keep about a week's worth.
# 
# Reports a currently copied into
#
#   /var/data/xt_static/utilities/data_transfer/maxisun/intl/csv
#
# But somewhere under xt_static may be better


DDATE=`date +%Y%m%d`
REPORT_DIR=/var/data/xt_static/utilities/data_transfer/maxisun/intl/csv

/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/do.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/dg.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/dgc.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/sku.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/season.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/desemp.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/supplier.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/poso.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/so.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/sg.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/sgr.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/sge.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/smd.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/smdr.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/rtv.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/store_credits.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/gift_credits.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/mainstock.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/samplestock.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/mainstock_audit.pl
/opt/xt/deploy/xtracker/script/data_transfer/maxisun/nap/intl/samplestock_audit.pl

# keep a copy of reports somewhere

cd ${REPORT_DIR}
mkdir ${DDATE}
/bin/cp -p *.csv ${DDATE}/.

# delete the ones older than 1 week

#/usr/bin/find ${REPORT_DIR} -mtime +8 xargs -exec rm -f {} \;

