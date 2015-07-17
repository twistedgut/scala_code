#!perl
# Finds all allocateable shipments, and sends allocate messages for them. This
# is a left-over from when we thought we'd run allocation as a periodic cron
# job rather than trying to actually capture where shipments change. We might
# still go back there, and if we do, this script should work nicely.

use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( schema_handle );
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw/:shipment_item_status/;
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

# Check we're in a PRL phase
die "This script only makes sense when PRL Rollout Phase is true" unless
    config_var('PRL', 'rollout_phase');

# Get a schema object
my $schema = schema_handle();

my $shipments_considered = 0;
my $shipments_out_of_date = 0;

# Find all shipments with open shipment items
my @shipments = $schema->resultset('Public::ShipmentItem')->search({
    shipment_item_status_id => { IN => [
        $SHIPMENT_ITEM_STATUS__NEW,
        $SHIPMENT_ITEM_STATUS__SELECTED
    ] }
})->search_related('shipment', {}, { distinct => 1 });

for my $shipment (@shipments) {
    # Skip it if it's on hold
    next if $shipment->is_on_hold;

    $shipments_considered++;

    # Does it have an existing allocation?
    my @existing_allocations = $shipment->allocations;
    # Does it generate a new allocation?
    my @new_allocations = $shipment->allocate({
        operator_id => $APPLICATION_OPERATOR_ID
    });

    # Print diagnostic about that
    if ( @new_allocations ) {
        $shipments_out_of_date++;

        my $description = (scalar @existing_allocations) ?
            'updated' : 'missing';
        printf(
            "Shipment [%d] - sent %s allocations [%s]\n",
            $shipment->id,
            $description,
            (join '; ', map { $_->id } @new_allocations)
        );

    }
}

printf( "Having considered %d shipments, %d required new allocate messages\n",
    $shipments_considered, $shipments_out_of_date );

