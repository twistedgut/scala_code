#!/usr/bin/env perl

=head1 NAME

picking_in_xtracker.t - Test picking in XTracker only (not IWS or PRL)

=head1 DESCRIPTION

Tests the picking functionality within XTracker.
Not relevant if we're using IWS or PRLs.

Do a few orders:

    1 - Normal Products Only
    2 - Physical Voucher Only
    3 - Normal + Physical + Virtual
    4 - Normal + Physical + Virtual on a HandHeld
    5 - Normal + Virtual
    6 - incomplete pick
    7 - incomplete pick, handheld

#TAGS fulfilment picking phase0 checkruncondition printer duplication whm

=cut

use NAP::policy "tt", 'test';
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
use Test::XTracker::PrintDocs;
use Test::XTracker::Artifacts::RAVNI;
use Test::XT::Data::Container;
use Test::XTracker::RunCondition
    iws_phase => [0],
    prl_phase => [0];
use Data::Dump  qw( pp );

my $schema = Test::XTracker::Data->get_schema;

# FIXME: NAP ONLY TEST
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
            label   => 'Order with Normal Product Only',
            pids    => [ $pids->[0] ],
            no_gift => 1,
            chklist => 1,
        },
        2   => {
            label   => 'Order with Physical Vouchers Only',
            pids    => [ $pids->[1] ],
        },
        3   => {
            label   => 'Order with Normal Product, Phys Voucher & Virt Voucher',
            pids    => $pids,
            has_virtual_pid => 1,
            chklist => 1,
        },
        4   => {
            label   => 'Order with Normal Product, Phys Voucher & Virt Voucher on a HandHeld',
            pids    => $pids,
            handheld=> 1,
            has_virtual_pid => 1,
        },
        5   => {
            label   => 'Order with Normal Product & Virt Voucher',
            pids    => [ $pids->[0], $pids->[2] ],
            has_virtual_pid => 1,
        },
        6   => {
            label   => 'Order with Normal Product, to test Incomplete Pick',
            pids    => [ $pids->[0] ],
        },
        7   => {
            label   => 'Order with Normal Product, to test Incomplete Pick, on a HandHeld',
            pids    => [ $pids->[0] ],
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

    # set virtual shipment items to be PICKED for purpose of test
    $order->discard_changes;
    my @items   = $order->shipments->first->shipment_items->all;
    foreach my $item ( @items ) {
        $item->create_related( 'shipment_item_status_logs', {
                                        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                                        operator_id             => $APPLICATION_OPERATOR_ID,
                                } );
        if ( $item->is_virtual_voucher ) {
            $item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED } );
            $item->create_related( 'shipment_item_status_logs', {
                                            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED,
                                            operator_id             => $APPLICATION_OPERATOR_ID,
                                    } );
            $item->create_related( 'shipment_item_status_logs', {
                                            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
                                            operator_id             => $APPLICATION_OPERATOR_ID,
                                    } );
        }
    }

    # Get shipment to picking stage
    my $skus    = $mech->get_order_skus();
    my $vskus   = Test::XTracker::Data->stripout_vvoucher_from_skus( $skus );
    my $print_directory = Test::XTracker::PrintDocs->new();
    $mech->test_direct_select_shipment( $ship_nr );
    $skus       = $mech->get_info_from_picklist($print_directory, $skus);

    if ( $test->{chklist} ) {
        # don't need to do this everytime
        $mech   = test_pick_shipment_list( $mech, $ship_nr, $skus, $vskus, 1 );
    }

    if ( $test_key == 6 or $test_key == 7 ) {
        test_incomplete_pick( $mech, $ship_nr, $sku_hash, $skus, $test_key, $test);
    }
    else {
        $mech = test_picking_shipment( $mech, $ship_nr, $sku_hash, $skus, $vskus, $test, 1 );
    }
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

        $mech->get_ok( '/Fulfilment/Picking' . $handheld );
        $mech->submit_form_ok({
                with_fields => {
                    shipment_id => $ship_nr,
                },
                button => 'submit'
            }, "Pick shipment");

        # make sure Virtual Voucher SKU's don't appear in the Page
        foreach my $sku ( keys %{ $vskus } ) {
            $mech->content_unlike( qr/$sku/, "Can't find Virtual Voucher SKU ($sku) in Page" );
        }
        my ($container_id) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );

        foreach my $ship_item ( @ship_items ) {
            my $variant     = $ship_item->get_true_variant;
            my $sku         = $variant->sku;
            if ( !exists $skus->{ $sku } ) {      # if the sku doesn't exists then it should be a virtual voucher
                if ( $test->{has_virtual_pid} && !$variant->product->is_physical ) {
                    next;
                }
                else {
                    fail( "Got SKU ($sku) which should be in $skus hash but isn't and not a virtual voucher, Shipment Item Id: ".$ship_item->id );
                }
            }

            my $status_log_rs= $ship_item->shipment_item_status_logs->search( undef, { order_by => 'id DESC' } );
            note "Picking Shipment Item: ".$ship_item->id.", for SKU: ".$sku;

            $mech->submit_form_ok({
                    with_fields => {
                        location => $skus->{$sku}{location}
                    },
                button => 'submit'
            }, "Location for $sku: ".$skus->{$sku}{location});

            $mech->submit_form_ok({
                    with_fields => {
                        sku => $sku
                    },
                    button => 'submit'
                }, "Picked $sku");
            $mech->submit_form_ok({
                with_fields => {
                    container_id => $container_id->as_barcode
                },
                button => 'submit'
            }, "Picked into container " . $container_id->as_barcode);

            # Perpertual inventory! - fill it out.
            # The while is here because if the count doesn't match it asks you to count again
            my $perp_count  = 0;
            while ( scalar $mech->find_all_inputs( name=>'input_value' ) ) {
                note "in Perp. Inventory loop";
                note $mech->uri;
                ++$perp_count;
                $mech->submit_form_ok({
                        with_fields => {
                            input_value => 1
                        },
                        button => 'submit'
                }, "Perpertual Inventory for location @{[$skus->{$sku}{location}]} - loop $perp_count");
            }

            $mech->no_feedback_error_ok();

            # check statuses have been picked and logged
            $ship_item->discard_changes;
            $status_log_rs->reset;
            cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED,
                                            'Shipment Item Status as expected' );
            cmp_ok( $status_log_rs->first->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED,
                                            'Shipment Item Status Logged correctly' );
        }

        $mech->has_feedback_success_ok( qr/The shipment has now been picked/, 'All Items Picked' )
                or do { diag $mech->uri; };

        # test should include a Virtual Voucher that shouldn't have been picked
        if ( $test->{has_virtual_pid} ) {
            foreach my $ship_item ( @ship_items ) {
                $ship_item->discard_changes;
                my $variant = $ship_item->get_true_variant;
                # this will mean it's the Virtual Voucher Shipment Item
                if ( defined $ship_item->voucher_variant_id && !$variant->product->is_physical ) {
                    cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED,
                                            "Virtual Voucher Shipment Item Id Status is STILL 'Picked' and hasn't changed" );
                }
            }
        }
    }

    return $mech;
}

=head2 test_pick_shipment_list

    $mech = test_pick_shipment_list( $mech, $ship_nr, $skus, $vskus, $oktodo );

This will test that a table of shipments to pick will only be displayed for
Manager level access to the picking page and not for operator level.

=cut

sub test_pick_shipment_list {
    my ( $mech, $ship_nr, $skus, $vskus, $oktodo )  = @_;

    SKIP: {
        skip "test_pick_shipment_list",1     if ( !$oktodo );

        note "Testing Initial Picking List Page Shows List for proper Operator Level";

        # Test with Operator level access Should NOT see list of Shipments
        Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Picking', $AUTHORISATION_LEVEL__OPERATOR );
        $mech->get_ok('/Fulfilment/Picking');
        $mech->content_unlike( qr/Shipments Awaiting Picking/, "Can't find Table of Shipments for Operator Auth Level" );

        # Test with Manager level access SHOULD see list of Shipments
        Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Picking', $AUTHORISATION_LEVEL__MANAGER );
        $mech->get_ok('/Fulfilment/Picking');
        $mech->content_like( qr/Shipments Awaiting Picking/, "Can find Table of Shipments for Manager Auth Level" );
        ok (
            $mech->look_down (
                _tag => 'td',
                sub {$_[0]->as_trimmed_text =~ /$ship_nr/}
            ),
            "Found Shipment Id in List"
        ) or diag $mech->content;

        # Test on HandHeld, shouldn't see ant Shipments even though a Manager
        $mech->get_ok('/Fulfilment/Picking?view=HandHeld');
        $mech->content_unlike( qr/Shipments Awaiting Picking/, "Can't find Table of Shipments for Manager Auth Level on HandHeld" );
    };

    return $mech;
}

=head2 test_incomplete_pick

=cut

sub test_incomplete_pick {
    my ( $mech, $ship_nr, $sku_hash, $skus, $test_counter, $test )  = @_;

    my $schema      = Test::XTracker::Data->get_schema;
    # run through in HandHeld mode for the 4th test
    my $handheld    = ( $test_counter == 6 ? '?view=HandHeld' : '' );

    note "Testing Incomplete Pick for a Shipment";

    # Test with Operator level access Should NOT see list of Shipments and make test quicker
    Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Picking', $AUTHORISATION_LEVEL__OPERATOR );

    my $wms_to_xt = Test::XTracker::Artifacts::RAVNI->new('wms_to_xt');

    $mech->get_ok( '/Fulfilment/Picking' . $handheld );
    $mech->submit_form_ok({
        with_fields => {
            shipment_id => $ship_nr,
        },
        button => 'submit'
    }, "Pick shipment");

    $wms_to_xt->expect_messages( {  messages => [ { type => 'picking_commenced' } ] } );

    $mech->follow_link_ok({ text => 'Incomplete Pick' }, 'declare incomplete pick');

    # we may, in the future, get one other message (an 'inventory_adjust'), but for the moment we only expect one

    $wms_to_xt->expect_messages( {  messages => [ { type => 'incomplete_pick' } ] } );

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );
    is($shipment->shipment_status_id, $SHIPMENT_STATUS__HOLD, 'the shipment is on hold');
    my $hold = $shipment->search_related('shipment_holds',{ },{
        order_by => { -desc => 'hold_date' },
        rows => 1,
    })->single;
    is($hold->shipment_hold_reason_id, $SHIPMENT_HOLD_REASON__INCOMPLETE_PICK, 'correct reason');
    is($hold->operator_id, $schema->resultset('Public::Operator')->find({username=>'it.god'})->id,'correct operator');
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

