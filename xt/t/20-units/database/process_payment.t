#!/usr/bin/env perl


use NAP::policy "tt",     'test';

use Test::XTracker::Data;
use Test::XTracker::Carrier;
use Test::XTracker::ParamCheck;
use Test::XTracker::Mock::PSP;

use XTracker::Constants::FromDB   qw(
                                        :channel
                                        :currency
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                        :renumeration_status
                                        :renumeration_class
                                        :renumeration_type
                                    );
use XTracker::Constants::Payment    qw( :psp_return_codes );

use XTracker::Config::Local             qw( config_var dc_address );


use_ok( 'XTracker::Database::OrderPayment', qw( process_payment ) );
can_ok( 'XTracker::Database::OrderPayment', qw( process_payment _create_invoice ) );

my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

note "Checking required parameters passed in to 'process_payment'";
Test::XTracker::ParamCheck->check_for_params(
    \&process_payment,
    'process_payment',
    [ $schema, 123456 ],
    [
        'No Schema Handle passed in XTracker::Database::OrderPayment::process_payment',
        'No Shipment Id passed in XTracker::Database::OrderPayment::process_payment',
    ],
    [ $schema->storage->dbh ],
    [ 'Invalid Schema Object passed' ],
);

$schema->txn_do( sub {
    my $order       = _create_an_order();
    my $shipment    = $order->shipments->first;

    note "Order Nr/Id: ".$order->order_nr."/".$order->id;
    note "Shipment Id: ".$shipment->id;

    # set-up data
    my $tmp;
    my $orig_inv;
    my $tenders = $order->tenders;
    my $renums  = $shipment->renumerations;
    $tenders->delete;
    $renums->delete;

    my $conf_section    = $order->channel->business->config_section;
    my $chk_conf_section;
    my $channel_info    = $schema->resultset('Public::Channel')->get_channel_details( $order->channel->name );
    my $psp_channel     = config_var('PaymentService_'.$channel_info->{config_section}, 'dc_channel');

    #
    # NON Card Payment
    #
    note "TESTING NON Card Payment";

    note "Call 'process_payment' for NON Card Payment (Store Credit etc.)";
    $shipment->update( { store_credit => 120, shipping_charge => 20 } );
    ( $tmp, $chk_conf_section ) = process_payment( $schema, $shipment->id );
    is( $tmp, $order->order_nr, "Process Payment returned Order Nr." );
    is( $chk_conf_section, $conf_section, "Process Payment returned expected Sales Channel" );
    $order->discard_changes;
    $shipment->discard_changes;
    $orig_inv   = _check_invoice( $shipment );

    note "Call 'process_payment' again no new Invoice should be generated";
    ( $tmp ) = process_payment( $schema, $shipment->id );
    is( $tmp, $order->order_nr, "2nd Call, Process Payment returned Order Nr." );
    $order->discard_changes;
    $shipment->discard_changes;
    $tmp    = $shipment->renumerations->search( {}, { order_by => 'me.id DESC' } )->first;
    cmp_ok( $tmp->id, '==', $orig_inv->id, "2nd Call, No new Invoice created" );

    #
    # Card Payment
    #
    note "TESTING Card Payment";

    # get rid of previous data
    $orig_inv->search_related( 'renumeration_items' )->delete;
    $orig_inv->search_related( 'renumeration_status_logs' )->delete;
    $orig_inv->delete;
    $shipment->update( { store_credit => 0, shipping_charge => 15 } );

    my $next_preauth        = Test::XTracker::Data->get_next_preauth( $schema->storage->dbh );

    # create an 'orders.payment' record
    Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref     => $next_preauth,
        preauth_ref => $next_preauth,
    } );

    # test failures first, pass in the failure code you want after 'FAIL-'
    note "Test 'process_payment' should fail";

    # Payment is voided/cancelled
    Test::XTracker::Mock::PSP->set_settle_payment_return_code( $PSP_RETURN_CODE__CANCELLED_VOIDED );
    dies_ok( sub { process_payment( $schema, $shipment->id ); },
                    "Card Payment: 'process_payment' dies for reason '10 - Payment is voided/cancelled'" );
    like( $@, qr/Payment could not be taken for this shipment. Please advise a Line Manager/,
                    "Card Payment: die message for reason '10' ok" );
    # 3 - Missing Info
    Test::XTracker::Mock::PSP->set_settle_payment_return_code( $PSP_RETURN_CODE__MISSING_INFO );
    dies_ok( sub { process_payment( $schema, $shipment->id ); },
                    "Card Payment: 'process_payment' dies for reason '3 - Missing Info'" );
    like( $@, qr/please try again or if the problem persists please advise a Line Manager/,
                    "Card Payment: die message for reason '3' ok" );

    #service is down
    Test::XTracker::Mock::PSP->set_settle_payment_return_code( '999' );
    dies_ok( sub { process_payment( $schema, $shipment->id ); },
                    "Card Payment: 'process_payment' dies for reason 'Service is down'" );
    like( $@, qr/Payment couldn't be taken for this shipment, please try again or/,
                    "Card Payment: die message for reason Service Down" );


    # Other Reason
    Test::XTracker::Mock::PSP->set_settle_payment_return_code( undef );
    dies_ok( sub { process_payment( $schema, $shipment->id ); },
                    "Card Payment: 'process_payment' dies for other reason" );
    like( $@, qr/Payment could not be taken for this shipment, please try again/,
                    "Card Payment: die message for other reason ok" );


    # test it now passes
    note "Test 'process_payment' should now pass";

    Test::XTracker::Mock::PSP->set_settle_payment_return_code( $PSP_RETURN_CODE__SUCCESS );
    ( $tmp, $chk_conf_section ) = process_payment( $schema, $shipment->id );
    is( $tmp, $order->order_nr, "Process Payment returned Order Nr." );
    is( $chk_conf_section, $conf_section, "Process Payment returned expected Sales Channel" );
    # check structure passed in to 'settle_payment' to make sure it's what was expected
    $tmp    = Test::XTracker::Mock::PSP->get_settle_data_in();
    is_deeply( $tmp, { channel => $psp_channel, coinAmount => 11500, reference => $next_preauth, currency => $shipment->order->currency->currency },
                            "Data passed in to 'settlet_payment' as expected ");

    $order->discard_changes;
    $shipment->discard_changes;
    $tmp    = $order->payments->first;
    cmp_ok( $tmp->fulfilled, '==', 1, "Orders Payment is 'fulfilled'" );
    is( $tmp->settle_ref, 'TEST_RESULT-'.$next_preauth, "Order Payment 'settle_ref' ok" );
    $orig_inv   = _check_invoice( $shipment );

    note "Call 'process_payment' again no new Invoice should be generated";
    ( $tmp ) = process_payment( $schema, $shipment->id );
    is( $tmp, $order->order_nr, "2nd Call, Process Payment returned Order Nr." );
    $order->discard_changes;
    $shipment->discard_changes;
    $tmp    = $shipment->renumerations->search( {}, { order_by => 'me.id DESC' } )->first;
    cmp_ok( $tmp->id, '==', $orig_inv->id, "2nd Call, No new Invoice created" );

    $schema->txn_rollback();
} );


done_testing();

# checks the Invoice created is as expected
sub _check_invoice {
    my $shipment    = shift;

    note "Checking Invoice";

    my $renum   = $shipment->renumerations->search( {}, { order_by => 'me.id DESC' } )->first;

    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'me.id ASC' } )->all;
    my @renum_items = $renum->renumeration_items->search( {}, { order_by => 'me.shipment_item_id ASC' } )->all;

    isa_ok( $renum, 'XTracker::Schema::Result::Public::Renumeration', "An Invoice was created" );
    cmp_ok( $renum->renumeration_type_id, '==', $RENUMERATION_TYPE__CARD_DEBIT, "Invoice: Type is 'Card Debit'" );
    cmp_ok( $renum->renumeration_class_id, '==', $RENUMERATION_CLASS__ORDER, "Invoice: Class is 'Order'" );
    cmp_ok( $renum->renumeration_status_id, '==', $RENUMERATION_STATUS__COMPLETED, "Invoice: Status is 'Completed'" );
    cmp_ok( $renum->shipping, '==', $shipment->shipping_charge, "Invoice: 'Shipping' is ".$shipment->shipping_charge );
    cmp_ok( $renum->store_credit, '==', $shipment->store_credit, "Invoice: 'Store Credit' is ".$shipment->store_credit );

    cmp_ok( scalar( @renum_items ), '==', scalar( @ship_items ), "Invoice: Number of Items matches Shipment Items (".scalar( @ship_items ).")" );
    foreach my $idx ( 0..$#renum_items ) {
        cmp_ok( $renum_items[$idx]->unit_price, '==', $ship_items[$idx]->unit_price, "Invoice Item: 'unit_price' same as for Shipment Item (".$ship_items[$idx]->unit_price.")" );
    }

    return $renum;
}

# create an order
sub _create_an_order {
    my $args    = shift;

    note "Creating Order";

    my($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 1,
    });

    my $ship_account    = Test::XTracker::Data->find_shipping_account( { carrier => config_var('DistributionCentre','default_carrier'), channel_id => $channel->id } );
    my $prem_postcode   = Test::XTracker::Data->find_prem_postcode( $channel->id );
    my $postcode        = ( defined $prem_postcode ? $prem_postcode->postcode :
                            ( $channel->is_on_dc( 'DC2' ) ? '11371' : 'NW10 4GR' ) );
    my $dc_address      = dc_address($channel);
    my $address         = Test::XTracker::Data->order_address( {
                                                address         => 'create',
                                                address_line_1  => $dc_address->{addr1},
                                                address_line_2  => $dc_address->{addr2},
                                                address_line_3  => $dc_address->{addr3},
                                                towncity        => $dc_address->{city},
                                                county          => '',
                                                country         => $args->{country} || $dc_address->{country},
                                                postcode        => $postcode,
                                            } );

    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    my $base = {
        customer_id => $customer->id,
        channel_id  => $channel->id,
        shipment_type => $SHIPMENT_TYPE__DOMESTIC,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id => $ship_account->id,
        invoice_address_id => $address->id,
    };


    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => $base,
        attrs => [
            { price => 100.00 },
        ],
    });

    return $order;
}

