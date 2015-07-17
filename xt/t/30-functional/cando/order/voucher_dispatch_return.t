#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use FindBin::libs;
use utf8;


use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::XTracker::PrintDocs;
use XTracker::Config::Local         qw( :DEFAULT dc_address );

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :authorisation_level
                                        :channel
                                        :renumeration_status
                                        :return_status
                                        :return_item_status
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                        :stock_action
                                    );
use XTracker::Database              qw( get_database_handle );
use XTracker::Database::Session;
use Test::XTracker::RunCondition
    export => [qw( $iws_rollout_phase $prl_rollout_phase )];

use Data::Dump  qw( pp );

my ($channel,$pids,$tmp);

my $schema = Test::XTracker::Data->get_schema;

$channel        = Test::XTracker::Data->get_local_channel();
my $channel_id  = $channel->id;

my $mech = Test::XTracker::Mechanize->new;
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::PRL',
    ],
    mech => $mech,
);

Test::XTracker::Data->set_department('it.god', 'Shipping');
__PACKAGE__->setup_user_perms;
$mech->do_login;

my $customer        = Test::XTracker::Data->find_customer( { channel_id => $channel_id } );
my $shipping_account= Test::XTracker::Data->find_shipping_account( {
                                        carrier => config_var('DistributionCentre','default_carrier'),
                                        channel_id => $channel_id
                                    } );
my $prem_postcode   = Test::XTracker::Data->find_prem_postcode( $channel_id );
my $postcode        = ( defined $prem_postcode
                        ? $prem_postcode->postcode . ( $channel->is_on_dc( 'DC1' ) ? ' 4GR' : '' )
                        : ( $channel->is_on_dc( 'DC1' ) ? 'NW10 4GR' : '11371' )
                      );
my $dc_address = dc_address($channel);
my $address         = Test::XTracker::Data->order_address( {
                                            address         => 'create',
                                            address_line_1  => $dc_address->{addr1},
                                            address_line_2  => $dc_address->{addr2},
                                            address_line_3  => $dc_address->{addr3},
                                            towncity        => $dc_address->{city},
                                            county          => '',
                                            country         => $dc_address->{country},
                                            postcode        => $postcode,
                                        } );

# go get some pids relevant to the db I'm using - channel is for test context
($channel,$pids) = Test::XTracker::Data->grab_products( {
            how_many => 1,
            phys_vouchers   => {
                how_many => 1,
                want_stock => 10,
                want_code => 10,
                value => '100.00',
            },
            virt_vouchers   => {
                value => '50.00',
                how_many => 1,
                want_code => 2,
            },
    } );
# make sure Voucher Codes get assigned
$pids->[1]{assign_code_to_ship_item}    = 1;
$pids->[2]{assign_code_to_ship_item}    = 1;

my %tests   = (
        'Physical Voucher Only' => {
            pids    => [ $pids->[1] ],
            chk_ship_cancel => 1,
        },
        'Physical Voucher + Normal SKU + Virtual Voucher'   => {
            pids    => [ $pids->[0], $pids->[1], $pids->[2] ],
            chk_return_for_normal => 1,
        },
        'Physical & Virtual Voucher Only' => {
            pids    => [ $pids->[1], $pids->[2] ],
            chk_ship_cancel => 1,
        },
    );

# create a couple of orders
foreach ( sort keys %tests ) {
    my $test    = $tests{ $_ };

    note "TESTING: $_";

    my ($order, $order_hash) = Test::XTracker::Data->create_db_order( {
            base => {
                customer_id => $customer->id,
                channel_id  => $channel_id,
                shipment_type => $SHIPMENT_TYPE__DOMESTIC,
                shipment_status => $SHIPMENT_STATUS__PROCESSING,
                shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
                shipping_account_id => $shipping_account->id,
                invoice_address_id => $address->id,
                gift_shipment => 1,
            },
            pids => $test->{pids},
            attrs => [
                { price => 100.00 },
            ],
        } );


    my $order_nr = $order->order_nr;
    $mech->order_nr($order_nr);

    if ( $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE} ) {
        note "Shipping Acc.: $shipping_account";
        note "Order Nr: $order_nr";
        note "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;
    }

    my ($ship_nr, $status, $category)   = gather_order_info();
    note "Shipment Nr: $ship_nr";

    # The order status might be Credit Hold. Check and fix if needed
    if ( $status eq "Credit Hold" ) {
        note 'Credit Hold';
        Test::XTracker::Data->set_department('it.god', 'Finance');
        $mech->reload;
        $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
        ($ship_nr, $status, $category) = gather_order_info();
    }
    is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

    # set shipment item logs
    $order->discard_changes;
    my @items   = $order->shipments->first->shipment_items->all;
    foreach my $item ( @items ) {
        $item->create_related( 'shipment_item_status_logs', {
                                        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                                        operator_id             => $APPLICATION_OPERATOR_ID,
                                } );
    }

    # Get shipment to packing stage
    my $print_directory = Test::XTracker::PrintDocs->new();
    my $skus    = $mech->get_order_skus();
    my $vskus   = Test::XTracker::Data->stripout_vvoucher_from_skus( $skus );
    if ($prl_rollout_phase) {
        Test::XTracker::Data::Order->allocate_order($order);
        Test::XTracker::Data::Order->select_order($order);
        my $container_id = Test::XT::Data::Container->get_unique_id({ how_many => 1 });
        $framework->flow_msg__prl__pick_shipment(
            shipment_id => $order->shipments->first->id,
            container => {
                $container_id => [keys %$skus],
            }
        );
    } else {
        $mech->test_direct_select_shipment( $ship_nr );
        $skus   = $mech->get_info_from_picklist($print_directory,$skus) if $iws_rollout_phase == 0;
        $mech->test_pick_shipment( $ship_nr, $skus );
    }

    # make sure all items are set as packed
    $order->discard_changes;
    @items  = $order->shipments->first->shipment_items->all;
    foreach my $item ( @items ) {
        if ( $item->is_virtual_voucher ) {
            $item->create_related( 'shipment_item_status_logs', {
                                            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED,
                                            operator_id             => $APPLICATION_OPERATOR_ID,
                                    } );
            $item->create_related( 'shipment_item_status_logs', {
                                            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
                                            operator_id             => $APPLICATION_OPERATOR_ID,
                                    } );
        }
        $item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED } );
        # activate the voucher code
        if ( $item->voucher_variant_id ) {
            $item->voucher_code->activate;
        }
    }

    test_dispatch_return( $mech, $channel, $test, $ship_nr, 1 );
}

done_testing;


=head2 test_dispatch_return

 $mech  = test_dispatch_return($mech,$channel,$test,$shipment_id,$oktodo)

This tests the Dispatch/Return process.

=cut

sub test_dispatch_return {
    my ($mech,$channel,$test,$ship_nr,$oktodo)      = @_;

    my $schema      = Test::XTracker::Data->get_schema;
    my $dbh         = $schema->storage->dbh;

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );
    my %vouch_items;
    my @vouch_codes;
    my %norm_items;

    my $tmp;

    SKIP: {
        skip "test_dispatch_return",1       if ( !$oktodo );

        note "TESTING Dispatch/Return";

        # get voucher codes for Vouchers
        # for later tests
        my @items   = $shipment->shipment_items->all;
        foreach my $item ( @items ) {
            if ( $item->voucher_variant_id ) {
                push @vouch_codes, $item->voucher_code;
            }
        }

        $mech->get_ok( $mech->order_view_url );
        $mech->follow_link_ok( { text_regex => qr{Dispatch/Return} } );

        $mech->submit_form_ok({
            with_fields => {
                refund_type_id  => 99,
                full_refund     => 0,
            },
            button  => 'submit',
        }, 'Dispatch/Return' );
        $mech->no_feedback_error_ok;
        $mech->has_feedback_success_ok(qr/Dispatch and Return completed successully/,"Shipment Dispatched & Returned");

        # check data out
        $shipment->discard_changes;
        my $return  = $shipment->return;
        my $invoice = $return->renumerations->first;
        @items      = $shipment->shipment_items->all;

        ok( defined $return, "Found Return" );
        ok( defined $invoice, "Found Invoice" );

        note "check Shipment Items";
        foreach my $item ( @items ) {
            if ( $item->voucher_variant_id ) {
                cmp_ok( $item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__CANCELLED,
                                "Voucher Item Status is 'Cancelled'" );
                ok( !defined( $item->voucher_code_id ), "Voucher Item Voucher Code Id is 'undef'" );
                $vouch_items{ $item->id }   = $item;
            }
            else {
                cmp_ok( $item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                                "Normal Item Status is 'Return Pending'" );
                $norm_items{ $item->id }    = $item;
            }
            # should be an Invoice Item for each item
            $tmp    = $item->renumeration_items->search( { renumeration_id => $invoice->id } )->count();
            cmp_ok( $tmp, '==', 1, "Shipment Item has an Invoice Item for the New Invoice" );
        }

        # check voucher codes are unassigned
        note "check Voucher Codes are un-assigned";
        foreach my $code ( @vouch_codes ) {
            $code->discard_changes;
            ok( !defined( $code->assigned ), "Voucher Code is UN-assigned: ".$code->code );
            $tmp    = $code->credit_logs->first;
            ok( !defined( $tmp ), "Voucher Code has no Credit Logs" );
        }

        # check an invoice was only created for normal products
        if ( $test->{chk_return_for_normal} ) {
            note "check Return with Normal Products";
            cmp_ok( $return->return_status_id, '==', $RETURN_STATUS__AWAITING_RETURN,
                                "Return Status is 'Awaiting Return'" );
            my @ret_items   = $return->return_items->all;
            cmp_ok( @ret_items, '>', 0, "Return has Return Items" );
            foreach my $ritem ( @ret_items ) {
                cmp_ok( $ritem->return_item_status_id, '==', $RETURN_ITEM_STATUS__AWAITING_RETURN,
                                "Return Item Status is 'Awaiting Return'" );
                ok( exists( $norm_items{ $ritem->shipment_item_id } ), "Return Item is for a Normal Product" );
            }
        }

        # check shipment has been cancelled
        if ( $test->{chk_ship_cancel} ) {
            note "check Shipment when Vouchers Only";
            cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__CANCELLED,
                            "Shipment Status is 'Cancelled'" );
            cmp_ok( $return->return_status_id, '==', $RETURN_STATUS__CANCELLED,
                            "Return Status is 'Cancelled'" );
            cmp_ok( $return->return_items->count(), '==', 0, "There are ZERO Return Items for the Return" );
            cmp_ok( $invoice->renumeration_status_id, '==', $RENUMERATION_STATUS__AWAITING_ACTION,
                            "Invoice Status is 'Awaiting Action'" );
            $tmp    = $shipment->shipment_notes->search( {}, { order_by => 'me.id DESC' } )->first;
            ok( defined( $tmp ), "Shipment has a Note" );
            like( $tmp->note, qr{Dispatch/Return:}, "Shipment Note is about 'Dispatch/Return'" );
            cmp_ok( $tmp->operator_id, '==', $APPLICATION_OPERATOR_ID, "Shipment Note created by 'APPLICATION OP ID'" );
        }
        else {
            note "check Shipment with Normal Products";
            # check shipment status is ok
            cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DISPATCHED,
                            "Shipment Status is 'Dispatched'" );
            cmp_ok( $invoice->renumeration_status_id, '==', $RENUMERATION_STATUS__PENDING,
                            "Invoice Status is 'Pending'" );
        }
    }

    return $mech;
}

#------------------------------------------------------------------------------------------------

sub setup_user_perms {
    Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR);
    # Perms needed for the order process
    for (qw/Airwaybill Dispatch Packing Picking Selection Labelling/ ) {
        Test::XTracker::Data->grant_permissions('it.god', 'Fulfilment', $_, $AUTHORISATION_LEVEL__MANAGER);
    }
}

# First time check that we can get the order via search
# Other times go straight to that url
sub gather_order_info {
  my ($order_nr) = @_;

  $mech->get_ok($mech->order_view_url);

  # On the order view page we need to find the shipment ID
  note $mech->order_view_url;
  my $ship_nr = $mech->get_table_value('Shipment Number:');


  my $status = $mech->get_table_value('Order Status:');


  my $category = $mech->get_table_value('Customer Category:');
  return ($ship_nr, $status, $category);
}
