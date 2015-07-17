#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Comms::DataTransfer   qw(:transfer_handles);

# this script will update the web_db where a variant has stock but its
# visibility is false, we need to set its visibility to true
# this is to fix issue [MERCH-82]

foreach my $channel qw( NAP OUTNET MRP ) {
    foreach my $environment qw(live staging) {
        my $web_dbh = get_transfer_sink_handle({ environment => $environment, channel => $channel })->{dbh_sink};

        my $web_query = "UPDATE product, stock_location SET product.is_visible = 'T' WHERE product.sku = stock_location.sku AND stock_location.no_in_stock > 0 AND product.is_visible = 'F';";

        my $sth = $web_dbh->prepare($web_query);
        $sth->execute();
        $web_dbh->commit();
        $sth->finish;
        $web_dbh->disconnect();
    }
}


1;
