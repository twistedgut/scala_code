#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

picking.t - Test picking

=head1 DESCRIPTION

Do a few orders:

    1 - Physical Voucher Only
    2 - Normal + Physical + Virtual
    3 - Normal + Virtual

#TAGS fulfilment picking checkruncondition duplication iws whm

=cut

use FindBin::libs;



use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Config::Local         qw( :DEFAULT );
use XTracker::Database::Shipment    qw( get_postcode_shipping_charges get_state_shipping_charges get_country_shipping_charges );

use XTracker::Constants           qw( :application );
use XTracker::Constants::FromDB   qw(
                                        :channel
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                        :authorisation_level
                                        :shipment_hold_reason
                                    );

use Test::XTracker::Artifacts::RAVNI;
use Test::XT::Flow;
use Test::XT::Data::Container;
use Test::XTracker::RunCondition
    iws_phase => [1,2];
use Data::Dump  qw( pp );

my $schema = Test::XTracker::Data->get_schema;

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
    ],
);
$framework->login_with_permissions({
    dept => 'Distribution Management',
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Selection',
        'Fulfilment/On Hold',
    ]}
});


my $channel_id  = $schema->resultset('Public::Channel')->search( { 'business.config_section' => 'NAP' }, { join => 'business' } )->first->id;
my($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 1,
    phys_vouchers   => {
        how_many => 1,
        want_stock => 3,
    },
    virt_vouchers   => {
        how_many => 1,
    },
});
my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel_id } );

Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel_id );


my $mech = Test::XTracker::Mechanize->new;
Test::XTracker::Data->set_department('it.god', 'Shipping');

__PACKAGE__->setup_user_perms;

$mech->do_login;

# get shipping account for Domestic DHL
my $shipping_account= Test::XTracker::Data->find_shipping_account({
    channel_id => $channel_id,
    acc_name   => 'Domestic',
    carrier    => 'DHL Express',
});

my $address = Test::XTracker::Data->create_order_address_in("current_dc_premier");

my %tests = (
        1   => {
            label   => 'Order with Physical Vouchers Only',
            pids    => [ $pids->[1] ],
        },
        2   => {
            label   => 'Order with Normal Product, Phys Voucher & Virt Voucher',
            pids    => $pids,
            has_virtual_pid => 1,
            chklist => 1,
        },
        3   => {
            label   => 'Order with Normal Product & Virt Voucher',
            pids    => [ $pids->[0], $pids->[2] ],
            has_virtual_pid => 1,
        },
    );

foreach my $test_key ( sort { $a <=> $b } keys %tests ) {
    my $test    = $tests{ $test_key };
    note "TESTING - ".$test->{label};

    my $pids_to_use = $test->{pids};
    my $sku_hash    = { map { ($_->{sku}, $_) } @{ $pids_to_use } };

    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        base => {
            customer_id => $customer->id,
            channel_id  => $channel_id,
            shipment_type => $SHIPMENT_TYPE__DOMESTIC,
            shipment_status => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
            shipping_account_id => $shipping_account->id,
            invoice_address_id => $address->id,
            shipping_charge_id => 4,   # UK Express
            gift_shipment => ( $test->{no_gift} ? 0 : 1 ),
        },
        pids => $pids_to_use,
        attrs => [
            { price => 100.00 },
        ],
    });

    my $order_nr = $order->order_nr;

    note "Shipping Acc.: $shipping_account";
    note "Order Nr: $order_nr";
    note "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;

    $mech->order_nr($order_nr);

    my ($ship_nr, $status, $category) = gather_order_info();
    note "Shipment Nr: $ship_nr";

    # The order status might be Credit Hold. Check and fix if needed
    if ($status eq "Credit Hold") {
        Test::XTracker::Data->set_department('it.god', 'Finance');
        $mech->reload;
        $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
        ($ship_nr, $status, $category) = gather_order_info();
    }
    is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

    # Get shipment to picking stage
    my $skus    = $mech->get_order_skus();
    my $vskus   = Test::XTracker::Data->stripout_vvoucher_from_skus( $skus );

    # Select the order and trigger shipment_request message
    $framework->flow_mech__fulfilment__selection
        ->flow_mech__fulfilment__selection_submit($ship_nr);

    #$mech->test_direct_select_shipment( $ship_nr );
    $mech = test_picking_shipment( $mech, $ship_nr, $sku_hash, $skus, $vskus, $test, 1 );
}

done_testing;


=head2 test_picking_shipment

    $mech = test_picking_shipment( $mech, $ship_nr, $sku_hash, $skus, $vskus, $test, $oktodo );

This will test the actual picking of a shipment.

=cut

sub test_picking_shipment {
    my ( $mech, $ship_nr, $sku_hash, $skus, $vskus, $test, $oktodo )  = @_;

    my $schema      = Test::XTracker::Data->get_schema;
    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );
    my @ship_items  = $shipment->shipment_items->all;
    # run through in HandHeld mode for the 4th test
    my $handheld    = ( $test->{handheld} ? '?view=HandHeld' : '' );

    SKIP: {
        skip "test_picking_shipment",1      if ( !$oktodo );

        note "Testing Picking a Shipment";

        # Test with Operator level access Should NOT see list of Shipments and make test quicker
        Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Picking', $AUTHORISATION_LEVEL__OPERATOR );

        my $framework = Test::XT::Flow->new_with_traits(
            traits => ['Test::XT::Flow::WMS'], mech => $mech );

        my ($container_id) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );

        # Fake a ShipmentReady from IWS
        $framework->flow_wms__send_shipment_ready(
            shipment_id => $shipment->id,
            container => {
                $container_id => [ keys %$skus ]
            },
        );

        foreach my $ship_item ( @ship_items ) {
            $ship_item->discard_changes;
            my $variant = $ship_item->get_true_variant;
            # this will mean it's the Virtual Voucher Shipment Item
            if ( defined $ship_item->voucher_variant_id && !$variant->product->is_physical ) {
                cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__NEW,
                        "Virtual Voucher Shipment Item Id Status is 'NEW'" );

            } else {
                cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED,
                        "Normal Shipment Item Id Status is 'Picked'" );

                my $status_log_rs= $ship_item->shipment_item_status_logs
                    ->search({
                        shipment_item_id => $ship_item->id,
                    },{
                        order_by => { -desc => 'date'},
                        rows => 1,
                    });

                cmp_ok( $status_log_rs->single->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED,
                        'Shipment Item Status Logged correctly' );
            }
        }
    }

    return $mech;
}


#------------------------------------------------------------------------------------------------

sub setup_user_perms {
  Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
  # Perms needed for the order process
  for (qw/Selection Picking/ ) {
    Test::XTracker::Data->grant_permissions('it.god', 'Fulfilment', $_, 2);
  }
}

# First time check that we can get the order via search
# Other times go straight to that url
sub gather_order_info {
  my ($order_nr) = @_;

  $mech->get_ok($mech->order_view_url);

  # On the order view page we need to find the shipment ID

  my $ship_nr = $mech->get_table_value('Shipment Number:');

  my $status = $mech->get_table_value('Order Status:');


  my $category = $mech->get_table_value('Customer Category:');
  return ($ship_nr, $status, $category);
}

