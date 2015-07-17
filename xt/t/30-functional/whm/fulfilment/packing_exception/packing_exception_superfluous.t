#!/usr/bin/env perl

=head1 NAME

packing_exception_superfluous.t - Packing Exception superfluous item handling

=head1 DESCRIPTION

Test the Packing Exception superfluous item handling.

Superfluous items can be cancelled shipment items, cancelled vouchers,
entirely unexpected items and entirely unexpected vouchers.

Setup as follows:

    - Create an order with multiple items/vouchers
    - Cancel some items and a voucher
    - Complete packing of the shipment
    - Should be sent to Confirm Tote Empty page
    - Go to pipeo page
    - Scan the cancelled items and some unexpected items and vouchers into
        a tote or set of totes
    - Go to packing exception page

Then do some tests.

#TAGS fulfilment packing packingexception iws whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::RunCondition(
    export => [
        qw( $iws_rollout_phase $prl_rollout_phase $distribution_centre ),
    ],
);


use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use XTracker::Config::Local qw( config_var );
use Test::XT::Data::Container;
use Test::XTracker::LocationMigration;
use Test::XTracker::Artifacts::RAVNI;
use Carp::Always;

# Start-up gubbins here. Test plan follows later in the code...
test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Data::Location',
    ],
);
$framework->clear_sticky_pages;
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        ( $iws_rollout_phase < 1 ? ('Fulfilment/Picking') : () ),
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Selection'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);

# create and pick the order
test_prefix("Setup: order shipment");
my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 5,
    phys_vouchers => { how_many => 1, want_stock => 2},
});
my $order_data = $framework->flow_db__fulfilment__create_order_selected( channel  => $channel, products => $pids, );
note "shipment $order_data->{'shipment_id'} created";
(undef, $order_data->{tote_id}) = $framework->task__picking($order_data->{shipment_object});

{
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

# Cancel some products
note "Cancelling Product 2,3 and Voucher 6 from Shipment";
$framework->flow_mech__customercare__orderview( $order_data->{'order_object'}->id );
$framework->flow_mech__customercare__cancel_shipment_item();
$framework->flow_mech__customercare__cancel_item_submit(
    $pids->[1]->{'sku'},
    $pids->[2]->{'sku'},
    $pids->[5]->{'sku'}
);
$framework->flow_mech__customercare__cancel_item_email_submit();

if ($prl_rollout_phase == 0) {
    $xt_to_wms->expect_messages({
        messages => [{
            details => {
                "shipment_id" => "s-" . $order_data->{shipment_id},
            },
            'type' => "shipment_request",
        }]
    });
}
}

# Pack shipment
test_prefix("Setup: pack shipment");
$framework->task__packing($order_data->{shipment_object}, {
    tote        => $order_data->{tote_id},
    tote_empty  => 0,
});

# We should now be at the PIPE-O page
test_prefix("Setup: PIPEO");
my ($pe_tote) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );
# scan in the cancelled items
$framework
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($pids->[1]->{'sku'})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($pe_tote)
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($pids->[2]->{'sku'})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($pe_tote)
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($pids->[5]->{'sku'})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($pe_tote)
# scan in some completely unexpected items
#(that for convenience have the same skus as things we already packed)
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($pids->[3]->{'sku'})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($pe_tote)
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($pids->[4]->{'sku'})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($pe_tote)
# Mark process as done
# and mark the tote as emtpy
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_mark_complete
    ->flow_mech__fulfilment__packing_emptytote_submit('yes');
note "Set up complete.";


note "start real tests.";
test_prefix("Packing Exception page");
$framework->without_datalite(
    flow_mech__fulfilment__packingexception => (),
);
my $data = $framework->mech->as_data->{exceptions};

# Make sure we find the right one rather than relying on the possibility of it being the last .
my $found_index=0;
my $superfluous = $data->{$channel->name}->{'Containers with Unexpected or Cancelled Items'};
foreach my $index (0..@{ $superfluous }) {
    $found_index=$index;
    last if $superfluous->[$index]->{'Container ID'}->{value} eq $pe_tote;
}

# assert previous container where the item existed prior to going through PIPE-O is displayed.
is($superfluous->[$found_index]->{'Original Tote'}, $order_data->{tote_id},
     'Found previous container displayed on PE page');

is($superfluous->[$found_index]->{'Container ID'}->{value}, $pe_tote,
     'Exception tote appears on PE page');
is($superfluous->[$found_index]->{'Cancelled Items'}, 3,
     'PE tote has 3 cancelled items');
is($superfluous->[$found_index]->{'Unexpected Items'}, 2,
     'PE tote has 2 orphaned items');

my @oi_data = grep { $_->{'Container'}->{value} eq $pe_tote } @{$data->{$channel->name}->{'Unexpected Items'}};

like($oi_data[0]->{'SKU'}->{value}, qr/$pids->[3]->{'sku'}|$pids->[4]->{'sku'}/ ,
     'Unexpected item displayed');
like($oi_data[1]->{'SKU'}->{value}, qr/$pids->[3]->{'sku'}|$pids->[4]->{'sku'}/ ,
     'Other orphaned item displayed');
is($oi_data[0]->{'Container'}->{value}, $pe_tote,
     'Unexpected items container displayed');
is($oi_data[1]->{'Container'}->{value}, $pe_tote,
     'Other orphaned item container displayed');

test_prefix("Packing Exception Container page");
$framework->mech->get_ok($data->{$channel->name}->{'Containers with Unexpected or Cancelled Items'}->[$found_index]->{'Container ID'}->{url});
$data = $framework->mech->as_data;
like($data->{orphaned_items}->[-1]->{'SKU'}->{value}, qr/$pids->[3]->{'sku'}|$pids->[4]->{'sku'}/ ,
     'Unexpected item displayed');
like($data->{orphaned_items}->[-2]->{'SKU'}->{value}, qr/$pids->[3]->{'sku'}|$pids->[4]->{'sku'}/ ,
     'Other orphaned item displayed');
like($data->{cancelled_items}->[-1]->{'SKU'}, qr/$pids->[1]->{'sku'}|$pids->[2]->{'sku'}|$pids->[5]->{'sku'}/ ,
     'Unexpected item displayed');
like($data->{cancelled_items}->[-2]->{'SKU'}, qr/$pids->[1]->{'sku'}|$pids->[2]->{'sku'}|$pids->[5]->{'sku'}/ ,
     'Unexpected item displayed');
like($data->{cancelled_items}->[-3]->{'SKU'}, qr/$pids->[1]->{'sku'}|$pids->[2]->{'sku'}|$pids->[5]->{'sku'}/ ,
     'Unexpected item displayed');

note "scan out orphans";
$data = $framework
    ->catch_error(
        'Unable to find an unexpected item with that SKU in this container',
        'Not an orphaned item',
        flow_mech__fulfilment__packingexception__viewcontainer_remove_orphan => $pids->[1]->{'sku'})
    ->flow_mech__fulfilment__packingexception__viewcontainer_remove_orphan($pids->[3]->{'sku'})
    ->flow_mech__fulfilment__packingexception__viewcontainer_remove_orphan($pids->[4]->{'sku'})
    ->mech->as_data();
is($data->{orphaned_items}, undef, "No orphaned items remaining on page");

# check that there's still things in the tote at this stage in the db
my $container_rs = $framework->schema->resultset('Public::Container')->find($pe_tote);
is($container_rs->shipment_items->count, 3, 'Three shipment items in PE container');
is($container_rs->orphan_items->count, 0, 'No orphaned items in PE container');


# check everything is removed once putaway ready button pressed
# let's also test phase 1
$framework->data__location__get_invar_location(); # create the Invar location
# this mess is because we could have two shipment items with the same variant_id
my @shipment_items = $container_rs->shipment_items->all;

my %quantity_tests;
for my $item (@shipment_items) {
    my $vid = $item->get_true_variant->id;
    my $t = Test::XTracker::LocationMigration->new({
        variant_id => $vid,
        _test_states => ['stock_status'], # cheating a bit
    });
    $t->snapshot('before');

    $quantity_tests{$vid} = $t;
}

$framework
    ->flow_mech__fulfilment__packingexception__viewcontainer_putaway_ready();

$_->snapshot('after') for values %quantity_tests;

is($container_rs->shipment_items->count, 0, 'No shipment items in PE container');
is($container_rs->orphan_items->count, 0, 'No orphaned items in PE container');

my $putaway_test = Test::XT::Fulfilment::Putaway->new_by_type({
    flow => $framework,
});
my %expected_diffs;
for my $item (@shipment_items) {
    $item->discard_changes;
    is(
        $item->shipment_item_status_id,
        $putaway_test->expected_cancel_status,
        'item cancelled',
    );
    ok(!defined $item->container_id,'item in no container');
    $expected_diffs{$item->get_true_variant->id}++;
}

if( $iws_rollout_phase ) {
    for my $vid (keys %quantity_tests) {
        $quantity_tests{$vid}->test_delta(
            from => 'before',
            to => 'after',
            stock_status => {
                'Main Stock' => $expected_diffs{$vid},
            },
        );
    }
}

done_testing();
