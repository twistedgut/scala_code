#!/usr/bin/env perl

=head1 NAME

units_without_shipment.pl

=head1 SYNOPSIS

Report only (dry run):

    units_without_shipment.pl --restrict_location "Sample Room" --show_progress

Delete erroneous units:

    units_without_shipment.pl --restrict_location "Sample Room" --show_progress --delete

Delete erroneous units in all locations (not recommended, see IMPORTANT NOTE below):

    units_without_shipment.pl --show_progress --delete

=head1 DESCRIPTION

Script to solve the problem of PIDs that are not physically in the Sample Room,
(or samples in other locations) but XTracker says the unit is still there after
return is complete.

Delete these shipment-less sample quantities from their locations.

We want to remove items from sample room where they have no related shipments
outstanding and were probably duplicated earlier in the process.

=head1 IMPORTANT NOTE

Be aware that if you remove stock from any other location apart from the
Sample Room, the stock may have been allocated to a sample cart, and then the
sample cart will become stuck.

=head1 See also

Jiras: WHM-1387, WHM-2625, DCOP-482 ...and other linked jiras

=cut

use NAP::policy;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw/schema_handle/;
use XTracker::Constants::FromDB qw(
    :shipment_class
    :shipment_item_status
    :shipment_status
    :shipment_type
    :variant_type
    :return_status
);

use IO::Handle;
*STDERR->autoflush;
*STDOUT->autoflush;

use Getopt::Long;
my $delete;
my $restrict_location;
my $show_progress;
GetOptions(
    "delete"              => \$delete,
    "restrict_location=s" => \$restrict_location,
    "show_progress"       => \$show_progress,
);

my $schema = schema_handle;

my $location_rs;
if ($restrict_location) {
    # A single location
    $location_rs = $schema->resultset('Public::Location')->search({
        location => $restrict_location,
    })
}
else {
    # All possible sample locations
    $location_rs = $schema->resultset('Public::Location')->search({
        'status.name' => { -in => ['Sample', 'Creative'] }
    }, {
        join => { 'location_allowed_statuses' => 'status' },
    });
}
print "Searching in locations:\n";
printf("* %s\n", $_->location) foreach $location_rs->all;

my $flow_status_rs = $schema->resultset('Flow::Status')->search({
    'name' => { -in => ['Sample', 'Creative'] }
});

my $sample_quantities = $schema->resultset('Public::Quantity')->search({
        'me.quantity' => {'>' => 0},
        'product_variant.type_id' => $VARIANT_TYPE__STOCK,
        'me.status_id'   => { -in => $flow_status_rs->get_column('id')->as_query() },
        'me.location_id' => { -in => $location_rs->get_column('id')->as_query() },
    }, {
        join => 'product_variant',
});
printf("Found %s units\n", $sample_quantities->count);

my $operator_id = $schema->resultset('Public::Operator')->search({
    name => 'Application'
})->slice(0,0)->single()->id();

my $progress_counter;
while (my $sample = $sample_quantities->next){
    print "." if $show_progress;
    $progress_counter++;
    print "| checked $progress_counter units...\n" if $show_progress && ($progress_counter % 100 == 0);
    my $variant = $sample->product_variant;
    my $channel_id = $sample->channel_id;
    my $original_shipment = $schema->resultset('Public::ShipmentItem')->search(
            {'stock_transfer.channel_id' => $channel_id,
             'me.variant_id' => $variant->id,
             'me.shipment_item_status_id' => [$SHIPMENT_ITEM_STATUS__DISPATCHED],
             'shipment.shipment_class_id' => $SHIPMENT_CLASS__TRANSFER_SHIPMENT,
            },
            {
                join => {'shipment' => {'link_stock_transfer__shipments' => 'stock_transfer'}}
            }
        )->slice(0,0)->single;
    if (!$original_shipment) {
        my $original_shipment_return = $schema->resultset('Public::ShipmentItem')->search(
            {
             'me.variant_id' => $variant->id,
             'me.shipment_item_status_id' => [ $SHIPMENT_ITEM_STATUS__RETURN_PENDING],
             'shipment.shipment_class_id' => $SHIPMENT_CLASS__TRANSFER_SHIPMENT,
             'returns.return_status_id'    =>  $RETURN_STATUS__AWAITING_RETURN,
            },
            {
                join => {'shipment' => 'returns'}
            }
        )->slice(0,0)->single;
        if (!$original_shipment_return){
            print("\n") if $show_progress;
            printf(sprintf ("This SKU %s (variant %s) in location '%s' has no dispatched shipment item",
                $variant->sku, $variant->id, $sample->get_location_name()));

            # Default is to NOT delete
            if ($delete) {
                $sample->update_and_log_sample({
                    delta => -($sample->quantity()),
                    operator_id => $operator_id,
                    notes => "Stock removed as lost by whm-1387_report_units_in_sample_room_without_shipment.pl script (see WHM-2625)",
                });
                print ", so the invalid stock has been removed";
            }
            print ".\n";
        }
    }
}
