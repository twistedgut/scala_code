package Test::XTracker::Order::Actions::ChangeShipmentItem;

use NAP::policy     qw( class test );

BEGIN {
    extends "NAP::Test::Class";
};

=head1 NAME

Test::XTracker::Order::Actions::ChangeShipmentItem

=head1 DESCRIPTION

Tests the 'XTracker::Order::Actions::ChangeShipmentItem' class. A mocked up
'XTracker::Handler' will be used to simulate a request being sent to the
handler.

Using a UNIT test to test this Handler as there is a need to check what
requests are made to the PSP.

=cut

use Test::XTracker::Data;

use XTracker::Order::Actions::ChangeShipmentItem    ();

use Test::XT::Data;

use Test::XTracker::Mock::WebServerLayer;
use Test::XTracker::Mock::LWP;

use XTracker::Constants::FromDB     qw( :return_item_status );


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
        how_many_variants => 2,
        ensure_stock_all_variants => 1,
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

=head2 test_psp_is_updated_when_payment_method_requires_it

Tests a call to Change Shipment Item when the Order's Payment Method
requires the PSP to be updated of any Basket Changes.

=cut

sub test_psp_is_updated_when_payment_method_requires_it : Tests {
    my $self = shift;

    # end point on the PSP that should be used
    my $psp_pre_paid_end_point  = Test::XTracker::Data->get_psp_end_point('Update Basket');
    my $psp_post_paid_end_point = Test::XTracker::Data->get_psp_end_point('Item Replacement');

    # Successful PSP Response
    my $psp_success_response = Test::XTracker::Data->get_general_psp_success_response();

    my $product_data = $self->{pids}[0];

    my $order_data = $self->{data}->new_order(
        channel  => $self->{channel},
        products => [ $product_data ],
    );
    my $order         = $order_data->{order_object};
    my $shipment      = $order_data->{shipment_object};
    my $shipment_item = $shipment->shipment_items->first;

    # get the original Vairant and then any
    # one of the Products other Variants
    my $orig_variant = $shipment_item->variant;
    my ( $new_variant ) = grep { $_->id != $orig_variant->id }
                            $product_data->{product}->variants->all;

    # make sure a Payment has been created on the Order
    $order->payments->delete;
    my $payment_args = Test::XTracker::Data->get_new_psp_refs();
    my $payment = Test::XTracker::Data->create_payment_for_order( $order, $payment_args );

    my $mock_lwp = Test::XTracker::Mock::LWP->new();
    $mock_lwp->enabled(1);


    note "Change Item when Payment Method requires PSP to be notified";
    $mock_lwp->clear_all->add_response_OK( $psp_success_response );
    Test::XTracker::Data->change_payment_to_require_psp_notification_of_basket_changes( $payment );

    $shipment_item = $self->_change_item_and_check_ok( $shipment, $shipment_item, $new_variant );
    my $request_str = $mock_lwp->get_last_request->as_string;
    like( $request_str, qr/${psp_pre_paid_end_point}/, "and the expected PSP Request was made to '${psp_pre_paid_end_point}'" );
    Test::XTracker::Mock::WebServerLayer->check_success_message_like( qr/Size change completed successfully/, "'Size Change Completed' message generated" );


    note "Change Item when Payment Method does NOT require the PSP to be notified";
    $mock_lwp->clear_all->add_response_OK();
    Test::XTracker::Data->change_payment_to_not_require_psp_notification_of_basket_changes( $payment );

    $shipment_item = $self->_change_item_and_check_ok( $shipment, $shipment_item, $orig_variant );
    my $last_request = $mock_lwp->get_last_request;
    ok( !defined $last_request, "NO Requests made to the PSP" )
                    or diag "ERROR - a Request was Made: " . $last_request->as_string;
    Test::XTracker::Mock::WebServerLayer->check_success_message_like( qr/Size change completed successfully/, "'Size Change Completed' message generated" );


    note "Change Item when Payment has been Fulfilled and PSP is required to be Notified";
    $mock_lwp->clear_all->add_response_OK( $psp_success_response );
    Test::XTracker::Data->change_payment_to_require_psp_notification_of_basket_changes( $payment );
    $payment->update( { fulfilled => 1 } );

    $shipment_item = $self->_change_item_and_check_ok( $shipment, $shipment_item, $new_variant );
    $request_str = $mock_lwp->get_last_request->as_string;
    like( $request_str, qr/${psp_post_paid_end_point}/, "and the expected PSP Request was made to '${psp_post_paid_end_point}'" );
    Test::XTracker::Mock::WebServerLayer->check_success_message_like( qr/Size change completed successfully/, "'Size Change Completed' message generated" );


    # stop mocking LWP
    $mock_lwp->enabled(0);
}

=head2 test_psp_is_updated_when_payment_method_requires_it_for_exchange_shipment

Tests a call to Change Shipment Item for an Exchange Shipment when the Order's
Payment Method requires the PSP to be updated of any Basket Changes. It tests
that only the PSP is contacted if the Exchange Shipment's 'has_packing_started'
flag is set to TRUE.

=cut

sub test_psp_is_updated_when_payment_method_requires_it_for_exchange_shipment : Tests {
    my $self = shift;

    # end point on the PSP that should be used
    my $psp_end_point = Test::XTracker::Data->get_psp_end_point('Item Replacement');

    # Successful PSP Response
    my $psp_success_response = Test::XTracker::Data->get_general_psp_success_response();

    my $product_data = $self->{pids}[0];

    my $order_data = $self->{data}->dispatched_order(
        channel  => $self->{channel},
        products => [ $product_data ],
    );
    my $order         = $order_data->{order_object};
    my $shipment      = $order_data->{shipment_object};
    my $shipment_item = $shipment->shipment_items->first;

    # get the original Vairant and then any
    # one of the Products other Variants
    my $orig_variant = $shipment_item->variant;
    my ( $new_variant ) = grep { $_->id != $orig_variant->id }
                            $product_data->{product}->variants->all;

    # make sure a Payment has been created on the Order
    $order->payments->delete;
    my $payment_args = Test::XTracker::Data->get_new_psp_refs();
    my $payment = Test::XTracker::Data->create_payment_for_order( $order, $payment_args );

    my $return = $self->{data}->qc_passed_return( {
        shipment_id => $shipment->id,
        items => {
            $shipment_item->id => {
                type => 'Exchange',
                exchange_variant_id => $new_variant->id,
            },
        },
    } );

    # get details of the Exchange
    my $exchange_shipment = $return->exchange_shipment;
    my $exchange_item     = $exchange_shipment->shipment_items->first;
    my $return_item       = $exchange_item->return_item_exchange_shipment_item_ids->first;

    my $mock_lwp = Test::XTracker::Mock::LWP->new();
    $mock_lwp->enabled(1);


    note "Change Item on Exchange Shipment when Payment Method requires PSP to be notified but Shipment's 'has_packing_started' flag is FALSE";
    $mock_lwp->clear_all->add_response_OK();
    $exchange_shipment->update( { has_packing_started => 0 } );
    Test::XTracker::Data->change_payment_to_require_psp_notification_of_basket_changes( $payment );

    $exchange_item = $self->_change_item_and_check_ok( $exchange_shipment, $exchange_item, $orig_variant );
    cmp_ok( $return_item->discard_changes->exchange_shipment_item_id, '==', $exchange_item->id,
                                    "and the Return Item's 'exchange_shipment_item_id' field points to the new Item record" );
    my $last_request = $mock_lwp->get_last_request;
    ok( !defined $last_request, "NO Requests made to the PSP" )
                    or diag "ERROR - a Request was Made: " . $last_request->as_string;
    Test::XTracker::Mock::WebServerLayer->check_success_message_like( qr/Size change completed successfully/, "'Size Change Completed' message generated" );


    note "Change Item on Exchange Shipment when Payment Method requires PSP to be notified and Shipment's 'has_packing_started' flag is TRUE";
    $mock_lwp->clear_all->add_response_OK( $psp_success_response );
    $exchange_shipment->update( { has_packing_started => 1 } );

    $exchange_item = $self->_change_item_and_check_ok( $exchange_shipment, $exchange_item, $new_variant );
    cmp_ok( $return_item->discard_changes->exchange_shipment_item_id, '==', $exchange_item->id,
                                    "and the Return Item's 'exchange_shipment_item_id' field points to the new Item record" );
    my $request_str = $mock_lwp->get_last_request->as_string;
    like( $request_str, qr/${psp_end_point}/, "and the expected PSP Request was made to '${psp_end_point}'" );
    Test::XTracker::Mock::WebServerLayer->check_success_message_like( qr/Size change completed successfully/, "'Size Change Completed' message generated" );


    note "Change Item on Exchange Shipment when Payment Method does NOT require PSP to be notified and Shipment's 'has_packing_started' flag is TRUE";
    $mock_lwp->clear_all->add_response_OK();
    Test::XTracker::Data->change_payment_to_not_require_psp_notification_of_basket_changes( $payment );

    $exchange_item = $self->_change_item_and_check_ok( $exchange_shipment, $exchange_item, $orig_variant );
    cmp_ok( $return_item->discard_changes->exchange_shipment_item_id, '==', $exchange_item->id,
                                    "and the Return Item's 'exchange_shipment_item_id' field points to the new Item record" );
    $last_request = $mock_lwp->get_last_request;
    ok( !defined $last_request, "NO Requests made to the PSP" )
                    or diag "ERROR - a Request was Made: " . $last_request->as_string;
    Test::XTracker::Mock::WebServerLayer->check_success_message_like( qr/Size change completed successfully/, "'Size Change Completed' message generated" );


    # stop mocking LWP
    $mock_lwp->enabled(0);
}

#------------------------------------------------------------------------------

# helper that will Change the Shipment Item for a Shipment & check it worked
sub _change_item_and_check_ok {
    my ( $self, $shipment, $old_item, $new_variant ) = @_;

    # get the New Variant in the required format
    my $new_variant_string = $new_variant->id . '_' . $new_variant->size->size . '_' . $new_variant->sku;

    my $mock_web_layer = $self->_get_mock_web_layer_using_default_payload( {
        order_id    => $shipment->order->id,
        shipment_id => $shipment->id,
        # specify the Shipment Item to Change
        'item-' . $old_item->id => 1,
        # specify the new Variant for the Shipment Item
        'exch-' . $old_item->id => $new_variant_string,
    } );

    # change the Item
    XTracker::Order::Actions::ChangeShipmentItem::handler( $mock_web_layer );
    $shipment->discard_changes;

    cmp_ok( $shipment->non_cancelled_items->count, '==', 1, "still only have ONE Non-Cancelled Shipment Item" );
    my $new_item = $shipment->non_cancelled_items->first;
    cmp_ok( $new_item->variant_id, '==', $new_variant->id, "and the Item is for the expected Variant" );

    # return the New Item Record
    return $new_item;
}

# helper to populate the GET Params of a Change Item
# request with common data that doesn't effect the tests
sub _get_mock_web_layer_using_default_payload {
    my ( $self, $args ) = @_;

    my %get_params = (
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
        '/CustomerCare/OrderSearch/ChangeShipmentItem',
        \%get_params,
    );
}

