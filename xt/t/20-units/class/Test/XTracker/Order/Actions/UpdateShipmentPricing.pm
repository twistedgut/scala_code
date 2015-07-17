package Test::XTracker::Order::Actions::UpdateShipmentPricing;

use NAP::policy     qw( class test );

BEGIN {
    extends "NAP::Test::Class";
};

=head1 NAME

Test::XTracker::Order::Actions::UpdateShipmentPricing

=head1 DESCRIPTION

Tests the 'XTracker::Order::Actions::UpdateShipmentPricing' class. A mocked up
'XTracker::Handler' will be used to simulate a request being sent to the
handler.

Using a UNIT test to test this Handler as there is a need to check what
requests are made to the PSP.

=cut

use Test::XTracker::Data;

use XTracker::Order::Actions::UpdateShipmentPricing     ();

use Test::XT::Data;

use Test::XTracker::Mock::WebServerLayer;
use Test::XTracker::Mock::LWP;

use XTracker::Utilities             qw( format_currency_2dp );

use JSON;
use List::Util                      qw( sum );


sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    my $data = Test::XT::Data->new_with_traits( {
        traits => [ qw(
            Test::XT::Data::Order
            Test::XT::Data::Return
        ) ]
    } );
    $self->{data} = $data;
}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup();

    $self->schema->txn_begin();

    my ( $channel, $pids ) = Test::XTracker::Data->grab_products( {
        how_many => 2,
    } );

    $self->{channel} = $channel;
    $self->{pids}    = $pids;
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown();

    $self->schema->txn_rollback();
}


=head1 TESTS

=head2 test_basket_update_when_prices_change

For Orders paid using a Payment Method that requires the PSP to be notified of changes,
this tests that when using the '/.*/.*/UpdateShipmentPricing' Handler and reducing the
Prices of Items so that the Order Value is reduced, checks that the PSP is notified.

Also in the case of Orders paid using Store Credit as well as a Payment that the Payment
is Cancelled and removed if the lower Order Value means that the Store Credit covers the
cost of the Order and therefore the Payment is no longer needed.

=cut

sub test_basket_update_when_prices_change : Tests {
    my $self = shift;

    my $json = JSON->new();

    # end point on the PSP that should be used
    my $psp_update_basket_end_point  = Test::XTracker::Data->get_psp_end_point('Update Basket');
    my $psp_cancel_payment_end_point = Test::XTracker::Data->get_psp_end_point('Cancel Payment');
    # this will be called as well as the ones above
    my $psp_threshold_end_point      = Test::XTracker::Data->get_psp_end_point('Value Threshold Check');

    # get the general PSP Success Response
    my $psp_success_response = Test::XTracker::Data->get_general_psp_success_response( {
        reference => 'TEST',
    } );

    # should use the standard price defaults
    # of 100 per item + 10 shipping charge
    # with two products these should add up to 210
    my $payment_amount      = 90;
    my $store_credit_amount = 120;

    my $order_data = $self->{data}->new_order(
        channel  => $self->{channel},
        products => $self->{pids},
        tenders  => [
            { type => 'card_debit',   value => $payment_amount },
            { type => 'store_credit', value => $store_credit_amount },
        ],
    );
    my $order          = $order_data->{order_object};
    my $shipment       = $order_data->{shipment_object};
    my @shipment_items = $shipment->shipment_items->all;

    # update Store Credit values
    $order->update( { store_credit => ( $store_credit_amount * -1 ) } );
    $shipment->update( { store_credit => ( $store_credit_amount * -1 ) } );

    # make sure a Payment has been created on the Order
    $order->payments->delete;
    my $payment_args = Test::XTracker::Data->get_new_psp_refs();
    my $payment      = Test::XTracker::Data->create_payment_for_order( $order, $payment_args );

    my $mock_lwp = Test::XTracker::Mock::LWP->new();
    $mock_lwp->enabled(1);


    note "Amend Pricing so there is still a need for a Payment - with Payment that doesn't require PSP to be updated";
    $mock_lwp->clear_all->add_response_OK( $psp_success_response );
    Test::XTracker::Data->change_payment_to_not_require_psp_notification_of_basket_changes( $payment );

    $self->_amend_pricing_and_check_ok( $shipment, $shipment_items[0], { unit_price => 50 } );
    cmp_ok( $mock_lwp->request_count, '==', 1, "only one request to the PSP made" );
    my $last_request = $mock_lwp->get_last_request;
    like( $last_request->as_string, qr/${psp_threshold_end_point}/, "and the request was to check the Threshold" );
    cmp_ok( $order->discard_changes->payments->count, '==', 1, "and the Payment is still attached to the Order" );
    Test::XTracker::Mock::WebServerLayer->check_success_message_unlike( qr/payment.*removed/, "Payment Removed message not in Success message" );


    note "Amend Pricing so there is still a need for a Payment - with Payment that DOES require PSP to be updated";
    Test::XTracker::Data->change_payment_to_require_psp_notification_of_basket_changes( $payment );
    $mock_lwp->clear_all
                # for the Basket Update request
                ->add_response_OK( $psp_success_response )
                # for the Threshold request
                ->add_response_OK( $psp_success_response )
    ;

    $self->_amend_pricing_and_check_ok( $shipment, $shipment_items[0], { unit_price => 30 } );
    cmp_ok( $mock_lwp->request_count, '==', 2, "two requests to the PSP made" );
    $last_request = $mock_lwp->get_next_request;
    like( $last_request->as_string, qr/${psp_update_basket_end_point}/, "the first request was to update the Basket" );
    $last_request = $mock_lwp->get_next_request;
    like( $last_request->as_string, qr/${psp_threshold_end_point}/, "the last request was to check the Threshold" );
    cmp_ok( $order->discard_changes->payments->count, '==', 1, "and the Payment is still attached to the Order" );
    Test::XTracker::Mock::WebServerLayer->check_success_message_unlike( qr/payment.*removed/, "Payment Removed message not in Success message" );


    note "Amend Pricing so that now Store Credit covers the Value of the Order";
    $mock_lwp->clear_all->add_response_OK( $psp_success_response );

    $self->_amend_pricing_and_check_ok( $shipment, $shipment_items[1], { unit_price => 40 } );
    cmp_ok( $mock_lwp->request_count, '==', 1, "one request made to the PSP made" );
    $last_request = $mock_lwp->get_last_request;
    like( $last_request->as_string, qr/${psp_cancel_payment_end_point}/, "and the request was to Cancel the Payment" );
    cmp_ok( $order->discard_changes->payments->count, '==', 0, "and the Payment has been Deleted from the Order" );
    Test::XTracker::Mock::WebServerLayer->check_success_message_like( qr/payment.*removed/, "Payment Removed message in Success message" );


    # stop mocking LWP
    $mock_lwp->enabled(0);
}

#------------------------------------------------------------------------------

# helper that will Amend the Item Price for a Shipment & check it worked
sub _amend_pricing_and_check_ok {
    my ( $self, $shipment, $item, $new_price ) = @_;

    my $card_debit_tender    = $shipment->order->card_debit_tender;
    my $original_debit_value = $card_debit_tender->value;

    my $item_id = $item->id;

    # make sure all parts of $new_price have a value
    $new_price->{ $_ } //= $item->$_    foreach ( qw( unit_price tax duty ) );

    # specifiy the new values or the originals
    my %item_price = (
        "price_${item_id}" => $new_price->{unit_price},
        "tax_${item_id}"   => $new_price->{tax},
        "duty_${item_id}"  => $new_price->{duty},
    );

    my $difference_in_value = sum(
        map { $item->$_ - $new_price->{ $_ } }
                qw( unit_price tax duty )
    );

    my $mock_web_layer = $self->_get_mock_web_layer_using_default_payload( {
        shipment_id => $shipment->id,
        %item_price,
    } );

    # change the Item
    XTracker::Order::Actions::UpdateShipmentPricing::handler( $mock_web_layer );
    $item->discard_changes;
    $card_debit_tender->discard_changes;

    my %expect_prices = (
        unit_price => format_currency_2dp( $item_price{ "price_${item_id}" } ),
        tax        => format_currency_2dp( $item_price{ "tax_${item_id}" } ),
        duty       => format_currency_2dp( $item_price{ "duty_${item_id}" } ),
    );
    my %got_prices = (
        map { $_ => format_currency_2dp( $item->$_ ) } qw( unit_price tax duty ),
    );
    cmp_deeply( \%got_prices, \%expect_prices, "Prices have been Amended" )
                    or diag "ERROR - Prices are not correct -\n" .
                            "Got: " . p( %got_prices ) . "\n" .
                            "Expected: " . p( %expect_prices );

    is(
        format_currency_2dp( $card_debit_tender->discard_changes->value ),
        format_currency_2dp( ( $original_debit_value - $difference_in_value ) ),
        "Card Debit Tender has been adjusted correctly"
    );

    return;
}

# helper to populate the GET Params of a Change Item Price
# request with common data that doesn't effect the tests
sub _get_mock_web_layer_using_default_payload {
    my ( $self, $args ) = @_;

    my %get_params = (
        submit        => 1,
        send_email    => 'no',
        email_from    => 'n',
        email_replyto => 'o',
        email_to      => 'e',
        email_subject => 'm',
        email_body    => 'a',
        email_content_type => 'text/plain',
        %{ $args },
    );

    return Test::XTracker::Mock::WebServerLayer->setup_mock_with_get_params(
        '/CustomerCare/OrderSearch/UpdateShipmentPricing',
        \%get_params,
    );
}

