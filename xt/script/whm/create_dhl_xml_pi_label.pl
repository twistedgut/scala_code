#!/opt/xt/xt-perl/bin/perl

use NAP::policy;
use XTracker::DHL::Label;
use XTracker::Database qw( get_database_handle get_schema_using_dbh );

my $shipment_id = shift;
my $box_id = shift;

my $dbh = get_database_handle( { name => 'xtracker', type => 'readonly' } );
my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );

my $box = $schema->resultset('Public::ShipmentBox')->find($box_id);
die "no box $box_id" unless ($box);
die "box $box_id isn't for shipment $shipment_id" unless ($box->shipment_id == $shipment_id);

XTracker::DHL::Label::create_dhl_xmlpi_label($dbh, $box->shipment, $box_id);

