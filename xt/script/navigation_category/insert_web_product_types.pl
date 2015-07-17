#!/opt/xt/xt-perl/bin/perl
##
# Inserts entries in the web db product_type table so
# we don't get missing foreign key problems
##

use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Comms::DataTransfer   qw(:transfer_handles);

foreach my $channel qw( NAP OUTNET MRP ) {
    foreach my $environment qw(live staging) {
        my $web_dbh = get_transfer_sink_handle({ environment => $environment, channel => $channel })->{dbh_sink};

        my $sth = $web_dbh->prepare("select code from product_type");
        $sth->execute();
        print "Initially, $channel $environment has ".$sth->rows()." product types\n";
        $sth->finish;

        $sth = $web_dbh->prepare("
            insert into product_type (code, description)
            values (?, ?)
            on duplicate key update description=description
        ");

        foreach my $code (1..999) {
            my $product_type = sprintf("%03d", $code);
            $sth->execute($product_type, $product_type);
        }

        $web_dbh->commit();
        $sth->finish;

        $sth = $web_dbh->prepare("select code from product_type");
        $sth->execute();
        print "Subsequently, $channel $environment has ".$sth->rows()." product types\n";
        $sth->finish;
        $web_dbh->disconnect();
    }
}


1;
