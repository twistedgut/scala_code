package Test::XTracker::Order::Actions::UpdateShipment;

use NAP::policy     qw( class test );

BEGIN {
    extends "NAP::Test::Class";
};

=head1 NAME

Test::XTracker::Order::Actions::UpdateShipment

=head1 DESCRIPTION

Tests the 'XTracker::Order::Actions::UpdateShipment' class. A mocked up
'XTracker::Handler' will be used to simulate a request being sent to the
handler.

Using a UNIT test to test this Handler as there is a need to check what
requests are made to the PSP.

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Shipping;

use XTracker::Order::Actions::UpdateShipment    ();

use Test::XT::Data;

use Test::XTracker::Mock::WebServerLayer;
use Test::XTracker::Mock::LWP;

use XTracker::Constants::FromDB     qw( :shipping_charge_class );
use XTracker::Utilities             qw( format_currency_2dp );

use JSON;


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
        how_many => 1,
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

=head2 test_basket_update_when_shipping_charge_changes

For Orders paid using a Payment Method that requires the PSP to be notified of changes,
this tests that when using the '/.*/.*/UpdateShipment' Handler to change the Shipping
Charge option which results in the Order Value being reduced, checks that the PSP is
notified.

Also in the case of Orders paid using Store Credit as well as a Payment that the Payment
is Cancelled and removed if the lower Order Value means that the Store Credit covers the
cost of the Order and therefore the Payment is no longer needed.

=cut

sub test_basket_update_when_shipping_charge_changes : Tests {
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
    # with one product this should add up to 110
    # make the payment only cover part of the Shipping
    my $payment_amount      = 5;
    my $store_credit_amount = 105;

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

    # create some new Shipping Charges and then assign one to the Shipment
    my $shipping_charges = Test::XTracker::Data::Shipping->create_shipping_charges_for_shipment( $shipment, [ 10, 8, 7, 4 ] );
    $shipment->update( { shipping_charge_id => $shipping_charges->{ship_charge_10}{charge_record}->id } );

    # make sure a Payment has been created on the Order
    $order->payments->delete;
    my $payment_args = Test::XTracker::Data->get_new_psp_refs();
    my $payment      = Test::XTracker::Data->create_payment_for_order( $order, $payment_args );

    my $mock_lwp = Test::XTracker::Mock::LWP->new();
    $mock_lwp->enabled(1);


    note "Change Shipment Charge so there is still a need for a Payment - with Payment that doesn't require PSP to be updated";
    Test::XTracker::Data->change_payment_to_not_require_psp_notification_of_basket_changes( $payment );
    $mock_lwp->clear_all->add_response_OK( $psp_success_response );

    $self->_update_shipment_check_ok( $shipment, $shipping_charges->{ship_charge_8} );
    cmp_ok( $mock_lwp->request_count, '==', 1, "only one request to the PSP made" );
    my $last_request = $mock_lwp->get_last_request;
    like( $last_request->as_string, qr/${psp_threshold_end_point}/, "and the request was to check the Threshold" );
    cmp_ok( $order->discard_changes->payments->count, '==', 1, "and the Payment is still attached to the Order" );
    Test::XTracker::Mock::WebServerLayer->check_success_message_unlike( qr/payment.*removed/, "Payment Removed message not in Success message" );


    note "Change Shipment Charge again so there is still a need for a Payment - with Payment that does require PSP to be updated";
    Test::XTracker::Data->change_payment_to_require_psp_notification_of_basket_changes( $payment );
    $mock_lwp->clear_all
                # for the Basket Update request
                ->add_response_OK( $psp_success_response )
                # for the Threshold request
                ->add_response_OK( $psp_success_response )
    ;

    $self->_update_shipment_check_ok( $shipment, $shipping_charges->{ship_charge_7} );
    cmp_ok( $mock_lwp->request_count, '==', 2, "two requests to the PSP made" );
    $last_request = $mock_lwp->get_next_request;
    like( $last_request->as_string, qr/${psp_update_basket_end_point}/, "the first request was to update the Basket" );
    $last_request = $mock_lwp->get_next_request;
    like( $last_request->as_string, qr/${psp_threshold_end_point}/, "the last request was to check the Threshold" );
    cmp_ok( $order->discard_changes->payments->count, '==', 1, "and the Payment is still attached to the Order" );
    Test::XTracker::Mock::WebServerLayer->check_success_message_unlike( qr/payment.*removed/, "Payment Removed message not in Success message" );


    note "Change Shipment Charge so that now Store Credit covers the Value of the Order";
    $mock_lwp->clear_all->add_response_OK( $psp_success_response );

    $self->_update_shipment_check_ok( $shipment, $shipping_charges->{ship_charge_4} );
    cmp_ok( $mock_lwp->request_count, '==', 1, "one request made to the PSP made" );
    $last_request = $mock_lwp->get_last_request;
    like( $last_request->as_string, qr/${psp_cancel_payment_end_point}/, "and the request was to Cancel the Payment" );
    cmp_ok( $order->discard_changes->payments->count, '==', 0, "and the Payment has been Deleted from the Order" );
    Test::XTracker::Mock::WebServerLayer->check_success_message_like( qr/payment.*removed/, "Payment Removed message in Success message" );


    # stop mocking LWP
    $mock_lwp->enabled(0);
}

#------------------------------------------------------------------------------

# helper that will Update the Shipment & check it worked
sub _update_shipment_check_ok {
    my ( $self, $shipment, $new_charge ) = @_;

    my $new_charge_rec  = $new_charge->{charge_record};
    my $expected_charge = $new_charge->{gross_charge};
    my $original_charge = $shipment->shipping_charge;

    my $card_debit_tender    = $shipment->order->card_debit_tender;
    my $original_debit_value = $card_debit_tender->value;

    my $mock_web_layer = $self->_get_mock_web_layer_using_default_payload( {
        order_id               => $shipment->order->id,
        shipment_id            => $shipment->id,
        shipping_charge_id     => $new_charge_rec->id,
        update_shipping_charge => 1,
        email                  => $shipment->email,
        telephone              => $shipment->telephone,
        mobile_telephone       => $shipment->mobile_telephone,
        packing_instruction    => $shipment->packing_instruction,
    } );

    # change the Item
    XTracker::Order::Actions::UpdateShipment::handler( $mock_web_layer );
    $shipment->discard_changes;

    is( format_currency_2dp( $shipment->shipping_charge ), format_currency_2dp( $expected_charge ),
                            "Shipping Charge Cost has been Updated on the Shipment" );
    cmp_ok( $shipment->shipping_charge_id, '==', $new_charge_rec->id, "and Shipping Charge Id has been Updated" );

    is(
        format_currency_2dp( $card_debit_tender->discard_changes->value ),
        format_currency_2dp( ( $original_debit_value - ( $original_charge - $expected_charge ) ) ),
        "Card Debit Tender has been adjusted correctly"
    );

    return;
}

# helper to populate the GET Params of Update Shipment
# request with common data that doesn't effect the tests
sub _get_mock_web_layer_using_default_payload {
    my ( $self, $args ) = @_;

    my %get_params = (
        gift => '',
        %{ $args },
    );

    return Test::XTracker::Mock::WebServerLayer->setup_mock_with_get_params(
        '/CustomerCare/OrderSearch/UpdateShipment',
        \%get_params,
    );
}

