use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";

use XTracker::Database qw( get_schema_using_dbh get_database_handle );

my $dbh = get_database_handle( { name => 'xtracker' } );

my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );

my @shipments = $schema->resultset('Public::Shipment')->search({shipment_status_id=>2},{order_by=>'id'})->all;
                                
STDOUT->autoflush(1);

my $total=scalar @shipments;                                         
my $counter;
foreach my $shipment ( @shipments ){
    unless ($shipment->shipment_items->all){
        $total--;
        next;
    }
    $shipment->apply_SLAs;
    print $shipment->id.": ".$shipment->sla_cutoff."\t".$shipment->sla_priority."\t".($total-(++$counter))." remaining\n"; 
}

