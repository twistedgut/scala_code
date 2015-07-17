#!/bin/bash
# This script generates the linkshare feeds for INTL channels and transfers them across using FTP.
# Please see PM-2036 and PM-3696 for more details

### linkshare
/opt/xt/xt-perl/bin/perl /opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/linkshare/generate_feed.pl -channel 1 3 5 >> /tmp/linkshare_generate_feed.log 2>&1 || true

## transfer
/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/linkshare_intl_trans.sh >> /tmp/linkshare_intl_trans.sh.log
