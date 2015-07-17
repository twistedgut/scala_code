#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib";
use FindBin::libs qw( base=lib_dynamic );
#use lib "../lib";

use XTracker::Database qw( get_database_handle) ;
use XTracker::DHL::RoutingRequest qw( get_dhl_destination_code set_dhl_destination_code );
use DateTime;

# connect to database
my $schema = get_database_handle
({
    name    => 'xtracker_schema',
    type    => 'transaction',
});

my $order    = $schema->resultset('Public::Orders')->search( undef, { rows => 1 } )->first;
my $shipment = $order->shipments->first;

print "Shipment Id: ".$shipment->id."\n";

$schema->txn_do( sub
{
    my $ship_addr = $shipment->shipment_address;
    $ship_addr->update
        ({
            towncity => 'Glasgow',
            county => 'Lanarkshire',
            postcode => 'G2 3QA',
            country => 'United Kingdom',
        });

    print "Starting Requests\n";
    my $start = DateTime->now;
    foreach ( 1..10 ) {
        print "Attempt: ".$_."\n";
        my $dest_code = get_dhl_destination_code( $schema->storage->dbh, $shipment->id );
        print "$dest_code\n";
    }

    my $finish = DateTime->now->subtract_datetime( $start );
    print "Time Taken: ".$finish->delta_seconds." seconds\n";
    $schema->txn_rollback();
});

$schema->storage->dbh->disconnect;
