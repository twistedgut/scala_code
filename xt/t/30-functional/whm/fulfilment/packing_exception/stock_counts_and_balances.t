#!/usr/bin/env perl
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)

=head1 NAME

stock_counts_and_balances.t

=head1 DESCRIPTION

Test that asserts quantities and balances of shipped items, missing and faulty items

RECIPE:

    - run log_stock so the balances in transaction log can be "reset" to
        whatever are the current rules
    - This just to ensure that it's consistent
    - create an order with 5 items
    - pipe the order at packing saying 2 are missing
    - at packing exception we assert that one is missing but the other
        supposed to be missing is only faulty
    - We fix the shipment and the tote is sent to the commissioner
    - We trigger picking of the two items that were replaced
    - We pack the order and we box it.
    - After that we do calculations on quantities and balances to assert
        that the values are matching what we expect them too

#TAGS fulfilment packing packingexception iws todo duplication whm

=head1 TODO

    * DCA-48: Re-enable in prl_phase > 0 when picking with PRLs work is done
    * DCA-1221: Wait until we've checked packing exception replacement picks with PRLs

=cut

use NAP::policy "tt", 'test';

use Test::XTracker::RunCondition(
    prl_phase => 0,
    export    => qw( $iws_rollout_phase ),
);


use Test::XTracker::Data qw/qc_fail_string/;
use Test::XT::Flow;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status :stock_action);
use XTracker::Database qw(:common);
use XTracker::Database::Logging         qw( log_stock );
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;

use Carp::Always;

# Start-up gubbins here. Test plan follows later in the code...
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::AppMessages',
        'Test::XT::Feature::PipePage',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::WMS',
    ],
);

$framework->clear_sticky_pages;
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Fulfilment/Picking',
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Selection'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);

# set up an amq read dir
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

# Shipment changes during PIPE
#
# Load up a shipment with 5 items. Pick, and place it on hold. Start to pack,
# which takes us to PIPE page. While on the PIPE page, cancel an item.

# Russle up 5 products
my $product_count = 5;

my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => $product_count });
my %products = map {; "P$_" => shift( @$pids ) } 1..(scalar @$pids);

# Fix quantities and balances first.
my $schema = Test::XTracker::Data->get_schema;
my $dbh = $schema->storage->dbh;

my $username = "it.god"; #$framework->mech->logged_in_as;


my $operator = $schema->resultset('Public::Operator')
    ->find({ username => $username });

# COUNT current quantities and store them for later.
for my $p (keys %products) {

    # "reset" balance counts
    log_stock(
        $dbh,
        {
            variant_id  => $products{$p}->{'variant_id'},
            action      => $STOCK_ACTION__MANUAL_ADJUSTMENT,
            quantity    => 0,
            operator_id => $operator->id,
            notes       => "Setting up XTDC tests, ignore the quantity, the balance SHOULD BE right",
            channel_id  => $channel->id
        }
    );

    my $var_quantity = $schema->resultset('Public::Quantity')
        ->search({ variant_id => $products{$p}->{'variant_id'} })
        ->get_column('quantity')
        ->sum;

    my $var_balance_rs = $schema->resultset('Public::LogStock')
        ->search(
            { variant_id => $products{$p}->{'variant_id'} },
            { order_by => 'date DESC', rows => 1 }
        )->single;

    $products{$p}->{'var_balance'} = $var_balance_rs->balance;

    # We need to force the balance to a "right" value so we can assert some basic truths...further dowwn the road
    #$var_balance_rs->balance($var_quantity);

    # vivify quantity in %product for later referall
    $products{$p}->{'var_quantity'} = $var_quantity;

}


my ($shipment_id, $order_id, $picking_sheet);

# Knock up a tote
my ($tote_id, $pipe_tote_id, $faulty_tote, $extra_tote) =
    Test::XT::Data::Container->get_unique_ids( { how_many => 4 } );

if ($iws_rollout_phase == 0) {
    # Create a shipment
    my $shipment = $framework->flow_db__fulfilment__create_order(
        channel  => $channel,
        products => [ map { $products{"P$_"} } 1..$product_count ],
    );

    $shipment_id = $shipment->{'shipment_id'};
    $order_id = $shipment->{'order_object'}->id;

    note "Picking shipment $shipment_id from order $order_id";

    # Select the order, and start the picking process
    $picking_sheet =
        $framework->flow_task__fulfilment__select_shipment_return_printdoc( $shipment_id );

    $framework
        ->flow_mech__fulfilment__picking
        ->flow_mech__fulfilment__picking_submit( $shipment_id );

    # Pick the items according to the pick-sheet
    for my $item (@{ $picking_sheet->{'item_list'} }) {
        my $location = $item->{'Location'};
        my $sku      = $item->{'SKU'};

        $framework->flow_mech__fulfilment__picking_pickshipment_submit_location( $location );
        $framework->flow_mech__fulfilment__picking_pickshipment_submit_sku( $sku );
        $framework->flow_mech__fulfilment__picking_pickshipment_submit_container( $tote_id );
    }

} else {
    # Create a shipment
    my $order_data = $framework->flow_db__fulfilment__create_order_selected(
        channel  => $channel,
        products => [ map { $products{"P$_"} } 1..$product_count ],
    );
    $shipment_id = $order_data->{'shipment_id'};
    $order_id    = $order_data->{'order_object'}->id;

    # Fake a ShipmentReady from IWS
    $framework->flow_wms__send_shipment_ready(
        shipment_id => $shipment_id,
        container => {
            $tote_id => [ map { $products{"P$_"}->{'sku'} } 1..5 ],
        },
    );
}

# Pack the items
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $shipment_id );

# Fail items
my @items_to_fail = @{$framework->mech->as_data()->{shipment_items}};

# Let's QC fail a couple of items whilst packing and provide a reason
$framework->errors_are_fatal(0);
$framework
    ->flow_mech__fulfilment__packing_checkshipment_submit(
        missing => [ map { $items_to_fail[$_]->{'shipment_item_id'} } 0 .. 1 ]
);
$framework->errors_are_fatal(1);

# Finish packing it on the PIPE page
for my $pid ( map {"P$_"} 1..5 ) {
    # Skip the two pids we're saying are missing
    next if $items_to_fail[0]->{'SKU'} eq $products{$pid}->{'sku'};
    next if $items_to_fail[1]->{'SKU'} eq $products{$pid}->{'sku'};
    $framework->flow_mech__fulfilment__packing_placeinpetote_scan_item( $products{$pid}->{'sku'} );
    $framework->flow_mech__fulfilment__packing_placeinpetote_scan_item( $pipe_tote_id );
}

$framework->flow_mech__fulfilment__packing_placeinpetote_mark_complete();

if ($iws_rollout_phase == 0) {
    # at this point we expect 3 messages :
    #   a shipment request
    #   a shipment received
    #   a shipment reject
    $xt_to_wms->expect_messages({
        messages => [
            {   '@type'   => 'shipment_request'  },
            {   '@type'   => 'shipment_received' },
            {   '@type'   => 'shipment_reject'   },
        ]
    });
} else {
    # at this point we expect 2 messages :
    #   a shipment received
    #   a shipment reject
    $xt_to_wms->expect_messages({
        messages => [
            {   '@type'   => 'shipment_received' },
            {   '@type'   => 'shipment_reject'   },
        ]
    });
}

# Let's now go and check the PackingException test,
# let's say re-iterate that the previous missing items are really missing
# and let's also say there's somthing else missing as well.
# 3 items will be missing in total

$framework
    ->flow_mech__fulfilment__packingexception
    ->flow_mech__fulfilment__packingexception_submit( $shipment_id )
    ->flow_mech__fulfilment__packingexception_shipment_item_mark_missing( $items_to_fail[0]->{'shipment_item_id'} )
    ->flow_mech__fulfilment__packing_checkshipmentexception_faulty( $items_to_fail[1]->{'SKU'} )
    ->flow_mech__fulfilment__packing_scanoutpeitem_sku( $items_to_fail[1]->{'SKU'} )
    ->flow_mech__fulfilment__packing_scanoutpeitem_tote( $faulty_tote )
    ->flow_mech__fulfilment__packing_checkshipmentexception_submit;

# Now we need to re-pick these missing/faulty items

# TODO: PRLs: there should be a new allocation, we need to pretend that's been picked

if ($iws_rollout_phase == 0) {
    # Select the new picking list, and start the picking process

    # Fetching a new picking list through flow_task__fulfilment__select_shipment_return_printdoc
    # doesn't work because it generates the same filename rather than a new one.

    $framework
        ->flow_mech__fulfilment__selection
        ->flow_mech__fulfilment__selection_submit( $shipment_id )
        ->flow_mech__fulfilment__picking
        ->flow_mech__fulfilment__picking_submit( $shipment_id );

    # Pick the items according to the pick-sheet
    for my $item (@{ $picking_sheet->{'item_list'} }) {
        my $location = $item->{'Location'};
        my $sku      = $item->{'SKU'};
        next unless ( $items_to_fail[0]->{'SKU'} eq $sku ||
                          $items_to_fail[1]->{'SKU'} eq $sku );

        # Just pick those problematic items
        $framework->flow_mech__fulfilment__picking_pickshipment_submit_location( $location );
        $framework->flow_mech__fulfilment__picking_pickshipment_submit_sku( $sku );
        $framework->flow_mech__fulfilment__picking_pickshipment_submit_container( $tote_id );
    }
} else {
    # Fake a ShipmentReady from IWS for the missing items.

    # PEC Mighty hack warning...
    # This shipment_ready message should contain all the items from the original shipment in their respective container
    # plus the items that were re-picked by system following the missing-item, size-change triggers.
    # We seem to be able to get away with just "faking" a shipment ready for the items to be re-picked.
    $framework->flow_wms__send_shipment_ready(
        shipment_id => $shipment_id,
        container => {
            $extra_tote => [ map {
                my $sku = $products{"P$_"}->{'sku'};
                # Skip the failed skus
                ( $sku eq $items_to_fail[0]->{'SKU'} || $sku eq $items_to_fail[1]->{'SKU'} ? $sku : () )
            } 1..5 ],
        },
    );
}

# Pack the items
$framework
    ->flow_mech__fulfilment__packing
    ->catch_error(
        qr/Please collect the following containers from the commissioner/,
        "Grab from commissioner",
        flow_mech__fulfilment__packing_submit => ( $shipment_id )
    );

# Now pack everything succesfully
$framework
    ->flow_mech__fulfilment__packing_checkshipment_submit();


# @items_to_fail contains all 5 items, not just the failed ones
for my $item (@items_to_fail) {
    my $sku      = $item->{'SKU'};
    $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $sku );
}

# Finish the packing process and prepare the box to be shipped
$framework->flow_mech__fulfilment__packing_packshipment_submit_boxes( channel_id => $channel->id );

if (XTracker::Config::Local::config_var(qw/DistributionCentre expect_AWB/)) {
    $framework->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789");
}

$framework->flow_mech__fulfilment__packing_packshipment_complete;

# Accounting for all the messages exchange otherwise big daddy will complain....
my @messages = (
        {
            details => {
                "shipment_id" => "s-$shipment_id",
                "from" => {"no" => "where"}
            },
            '@type' => "item_moved"
        },
        {
            details => {
                "shipment_id" => "s-$shipment_id",
                "from" => {"no" => "where"}
            },
            '@type' => "item_moved"
        },
        {
            details => {
                "shipment_id" => "s-$shipment_id",
                pause => 0
            },
            '@type' => "shipment_wms_pause"
        },
        {
            details => { "shipment_id" => "s-$shipment_id" },
            '@type' => "shipment_received"
        },
        {
            details => { "shipment_id" => "s-$shipment_id" },
            '@type' => "shipment_packed"
        }
);
if ($iws_rollout_phase == 0) {
    push @messages,
        {
            details => { "shipment_id" => "s-$shipment_id" },
            '@type' => "shipment_request"
        }
    ;
}
$xt_to_wms->expect_messages({
    messages => \@messages
});

note "Checking product counts...";

for my $p (keys %products) {
    my $var_quantity = $schema->resultset('Public::Quantity')
        ->search({ variant_id => $products{$p}->{'variant_id'} })
        ->get_column('quantity')->sum;

    my $var_balance = $schema->resultset('Public::LogStock')
        ->search(
            { variant_id => $products{$p}->{'variant_id'} },
            { order_by => 'date DESC', rows => 1 }
        )->single->balance;


    note sprintf("Checking current product %s quantity against current balance, SKU %s, Variant %s",
            $p,
            $products{$p}->{'sku'},
            $products{$p}->{'variant_id'});

    note "We marked sku as missing ".$items_to_fail[0]->{'SKU'} if $items_to_fail[0]->{'SKU'} eq $products{$p}->{'sku'};
    note "We marked sku as faulty  ".$items_to_fail[1]->{'SKU'} if $items_to_fail[1]->{'SKU'} eq $products{$p}->{'sku'};

    note "Original balance for $p was        ".$products{$p}->{'var_balance'};
    note "Original quantity for $p was       ".$products{$p}->{'var_quantity'};
    note "Current quantity for $p is         ".$var_quantity;
    note "Current balance  for $p is         ".$var_balance;

    if ( $items_to_fail[0]->{'SKU'} eq $products{$p}->{'sku'} ) {
        # missing
        is($products{$p}->{'var_quantity'}-2,$var_quantity,
           "Previous quantity adjusted matches current balance $var_quantity in $p");
        is($products{$p}->{'var_balance'}-2,$var_balance,
           "Previous balance adjusted matches current balance $var_balance in $p");
        my $middle_balance = $schema->resultset('Public::LogStock')
            ->search(
                {
                    variant_id => $products{$p}->{'variant_id'},
                    notes => { -ilike => 'missing item %' },
                },
                { order_by => 'date DESC', rows => 1 }
            )->single->balance;
        is($products{$p}->{'var_balance'}-1,$middle_balance,
           "Previous balance adjusted matches intermediate balance $middle_balance in $p");
    } elsif ( $items_to_fail[1]->{'SKU'} eq $products{$p}->{'sku'} ) {
        # Faulty
        is($products{$p}->{'var_quantity'}-1,$var_quantity,
           "Previous quantity adjusted matches current balance $var_quantity in $p");
        is($products{$p}->{'var_balance'}-2,$var_balance,
           "Previous balance adjusted matches current balance $var_balance in $p");
        my $middle_balance = $schema->resultset('Public::LogStock')
            ->search(
                {
                    variant_id => $products{$p}->{'variant_id'},
                    notes => { -ilike => 'Faulty: %' },
                },
                { order_by => 'date DESC', rows => 1 }
            )->single->balance;
        is($products{$p}->{'var_balance'}-1,$middle_balance,
           "Previous balance adjusted matches intermediate balance $middle_balance in $p");
    } else {
        # the other cases
        is($products{$p}->{'var_quantity'}-1,$var_quantity,
           "Previous quantity adjusted matches current balance $var_quantity in $p");
        is($products{$p}->{'var_balance'}-1,$var_balance,
           "Previous balance adjusted matches current balance $var_balance in $p");
    }

}


done_testing();
