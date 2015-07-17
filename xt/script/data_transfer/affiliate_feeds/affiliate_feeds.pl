#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;
## no critic(ProhibitBacktickOperators)
### froogle
# switched off - now produced by website
#`/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/froogle/generate_feed.pl`;
### glam
`/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/glam/generate_feed.pl`;
### aff window
`/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/aff_window/generate_feed.pl`;

