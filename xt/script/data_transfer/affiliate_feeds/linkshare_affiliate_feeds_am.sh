#!/bin/bash
# This script generates the linkshare feeds for AM channels and transfers them across using FTP.
# Please see PM-2036 and PM-3696 for more details

### linkshare
/opt/xt/xt-perl/bin/perl /opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/linkshare/generate_feed.pl -channel 2 4 6 >> /tmp/linkshare_generate_feed.log 2>&1 || true

## transfer
/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/linkshare_am_trans.sh >> /tmp/linkshare_am_trans.sh.log
