#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;

=head1 DESCRIPTION

This script will either:

* update all shipment items affected by WHM-617 so that they have the
correct status, and log the changes in shipment_item_status_log

or:

* produce SQL to do the same thing, for a simpler and quicker BAU

=cut

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Config::Local qw( config_var config_section_slurp );
use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw( :shipment_item_status );
use XTracker::Database qw( :common );
use Getopt::Long;
use Pod::Usage;

my %opt = (
    dryrun => 0,
    action => 'sql',
);

my $result = GetOptions( \%opt,
    'dryrun|d',
    'startdate|s=s',
    'action|a=s',
);

$opt{'startdate'} ||= '2012-01-12 08:21:25';
unless ($opt{'action'} eq 'sql' || $opt{'action'} eq 'update') {
    die "action must be either 'sql' or 'update'";
}

my ($schema) = get_schema_and_ro_dbh('xtracker_schema');

my @potential_problem_shipment_items = $schema->resultset('Public::ShipmentItem')->search(
    {
        'me.shipment_item_status_id' => $SHIPMENT_ITEM_STATUS__DISPATCHED,
        'shipment_item_status_logs.shipment_item_status_id' => $SHIPMENT_ITEM_STATUS__DISPATCHED,
        'shipment_item_status_logs.date' => {'>=' => $opt{'startdate'}},
    },
    {
        join => 'shipment_item_status_logs'
    }
)->all;

foreach my $potential (@potential_problem_shipment_items) {
    my @statuses = $potential->shipment_item_status_logs->search(
        {},
        {
            'order_by' => {-desc => 'date'},
            'rows' => 2,
        }
    )->all;
    if ($statuses[1]->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__CANCELLED
        || $statuses[1]->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING) {
        if ($opt{'action'} eq 'sql') {
            print "update shipment_item set shipment_item_status_id = ".$statuses[1]->shipment_item_status_id." where id = ".$potential->id.";\n";
            print "insert into shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator, date) values (".$potential->id.", ".$statuses[1]->shipment_item_status_id.", ".$APPLICATION_OPERATOR_ID.", now());\n";
        } else {
            if ($opt{'dryrun'}) {
                print "Would have reverted status to ".$statuses[1]->shipment_item_status_id." for shipment item ".$potential->id." from shipment ".$potential->shipment_id."\n";
            } else {
                $potential->update_status($statuses[1]->shipment_item_status_id, $APPLICATION_OPERATOR_ID);
                print "Reverted status to ".$statuses[1]->shipment_item_status_id." for shipment item ".$potential->id." from shipment ".$potential->shipment_id."\n";
            }
        }
    }
    
}
