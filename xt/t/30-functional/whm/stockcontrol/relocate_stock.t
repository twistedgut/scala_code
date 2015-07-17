#!/usr/bin/env perl

=head1 NAME

relocate_stock.t - Perform stock relocation

=head1 DESCRIPTION

Perform stock relocation to check that the stock relocation routine, invoked via

    /StockControl/StockRelocation

and

    /StockControl/RelocateStock

...actually does the relocation requested.

=head2 Part One

We find a location that contains stock, then create a test location.

=head2 Part Two

Then we fetch the /StockControl/StockRelocation URI,
and submit to it in three steps:

    * first to present the 'from' location,
    * then the 'to' location,
    * then confirm the update.

=head2 Part Three

We then iterate through all the items at the original
location, and make sure that each one is now in the
new location, and the quantities match.

Note that we skip zero-quantity items at the original
location, because moving zero-quantity items:

   * isn't supported by Quantity->move_stock
   * doesn't make sense anyway

Those items are just left behind in the old location.

#TAGS inventory relocate phase0 whm

=cut

use NAP::policy "tt", 'test';

use FindBin::libs;

use Test::XT::Flow;
use Test::XT::Data::Location;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :flow_status
);
use XTracker::Database qw(:common);
use Test::XTracker::Data;
use Test::Differences;

# just for testing...
use XTracker::Database::Location qw( get_stock_in_location);
use Test::XTracker::RunCondition iws_phase => 0;
use Data::Dumper;
use Data::Dump 'pp';

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::StockControl',
        'Test::XT::Data::Location',
    ],
);

$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Stock Control/Stock Relocation'
    ]}
});

my $schema = $framework->schema;

note "Destroying test locations";
$framework->data__location__destroy_test_locations;

my ( $new_location ) = $framework->data__location__create_new_locations;
my $location = $schema->resultset('Public::Location')->find( { location => $new_location } );

# Part One:

note 'Ensuring we have at least one enabled channel';

my $enabled_channels = $schema->resultset('Public::Channel')->enabled;
cmp_ok( $enabled_channels->count, '>', 0, 'We have at least 1 enabled channel' );

note "Finding a location with movable stock";

my( $channel, $pids ) = Test::XTracker::Data->grab_products({
    channel => 'nap',
    how_many => 20,
    ensure_stock_all_variants => 1,
    channel => $enabled_channels->single,
    dont_ensure_stock => 1,
});

foreach my $variant( @{$pids} ) {

    my $original_location_obj = Test::XTracker::Data->ensure_stock(
        $variant->{'pid'},
        $variant->{'size_id'},
        $channel->id,
        $location->id
    ) || die "ensure_stock() fails to return a location for " . $variant->{'pid'};

    # Make sure we don't have any quantities disabled channels at this location
    # (just a precaution if a test doesn't clean up after itself)
    my $disabled_channel_rs = $channel->result_source->resultset->search({ is_enabled => 0 });
    $original_location_obj->search_related('quantities', {
        channel_id => { -in => $disabled_channel_rs->get_column('id')->as_query }
    })->delete;

    my $variant = $schema->resultset('Public::Variant')
                         ->find( $variant->{variant_id} )
        || die "Could not find variant $variant->{variant_id}";

    my $original_quantity_obj = $variant->find_related('quantities', {
        channel_id => $channel->id,
        status_id   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        location_id => $original_location_obj->id,
    });
    unless ( $original_quantity_obj ) {
        die sprintf(
            'Could not find main stock quantity for channel_id %d location_id %d variant %s',
            $channel->id, $original_location_obj->id, pp $variant->{_column_data}
        );
    }

    my $original_location_name  = $original_location_obj->location;
    my $original_quantity       = $original_quantity_obj->quantity;

    note "Got current location '$original_location_name' with movable stock";
    my $location_opts = {
        quantity => 1,
        allowed_types => [ $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS ],
    };

    note "Creating a location of type @{$location_opts->{allowed_types}}";

    my ($new_location_name) = @{$framework->data__location__create_new_locations($location_opts)};

    my ($new_location_obj) = $schema->resultset("Public::Location")->find({
        location => $new_location_name
    });

    note "Got new location '$new_location_name'";

    # we need to capture the list of products, and the quantities, in that location

    my $location_stock = get_stock_in_location($framework->dbh, $original_location_name);

    # Part Two:

    $framework->flow_mech__stockcontrol__stockrelocation
          ->flow_mech__stockcontrol__stockrelocation_submit($original_location_name,$new_location_name);

    ok(!$framework->mech->app_error_message,'No error message after move');

    # Part Three:

    # Now we check that it's moved
    STOCK_ITEM:
    foreach my $original_stock_item (@{$location_stock}) {
        my ($variant_id,$quantity,$item_channel)=@{$original_stock_item}{qw(id quantity sales_channel)};

        unless ($quantity) {
            note "Skipping zero-quantity variant $variant_id";

            next STOCK_ITEM;
        }

        unless (defined $item_channel && $item_channel eq $channel->name) {
            if (defined $item_channel) {
            note "Skipping wrongly-channelized variant $variant_id (in "
                 .$item_channel." instead of ".$channel->name.")";
            }
            else {
            note "Skipping un-channelized variant $variant_id";
            }

            next STOCK_ITEM;
        }

        note "Variant: $variant_id";
        note "Quantity: $quantity";

        my $new_quantity = $schema->resultset("Public::Quantity")->find({
                channel_id  => $channel->id,
                variant_id  => $variant_id,
                status_id   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                location_id => $new_location_obj->id,
            });
        ok($new_quantity, "quantity created as expected");
        next STOCK_ITEM unless $new_quantity;

        note "New Location: ".$new_quantity->location->location;
        note "New Quantity: ".$new_quantity->quantity;

        is($new_quantity->location->location, $new_location_name,
            "Variant $variant_id now in '$new_location_name'");

        is($new_quantity->quantity, $quantity,
            "Variant $variant_id quantity is still $quantity");
    }
}

note "Destroying test locations";
$framework->data__location__destroy_test_locations;

done_testing();
