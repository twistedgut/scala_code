package Test::XT::DC::Controller::PreOrder::BulkRelease::UpdateOrderStatus;
use NAP::policy qw( test class );

BEGIN { extends 'NAP::Test::Class' }

=head1 NAME

Test::XT::DC::Controller::PreOrder::BulkRelease::UpdateOrderStatus

=head1 DESCRIPTION

Test the L<XT::DC::Controller::PreOrder::BulkRelease::UpdateOrderStatus> class.

=cut

use JSON;
use Mock::Quick;
use Catalyst::Test 'XT::DC';
use HTTP::Request::Common;
use Test::XTracker::Data::PreOrder;
use XTracker::Constants '$APPLICATION_OPERATOR_ID';
use XTracker::Constants::FromDB qw(
    :shipment_status
    :shipment_hold_reason
);

=head1 TESTS

=head2 startup

=cut

sub test_startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{has_permission} = 1;

    # Fake the response from the ACL has_permission method, so we can test
    # the API with and without permissions.
    $self->{acl} = qtakeover( 'XT::AccessControls' );
    $self->{acl}->override( has_permission => sub { return $self->{has_permission} } );

    # We need to fake the application session, so it thinks we're logged in.
    # We're not testing authentication, so this just returns static data.
    $self->{xtdc} = qtakeover( 'XT::DC' );
    $self->{xtdc}->override( session => sub { return { operator_id => $APPLICATION_OPERATOR_ID, user_id => 'it.god' } } );

}

sub test_shutdown : Test( shutdown => no_plan ) {
    my $self = shift;
    $self->SUPER::shutdown;

    # Explicitly restore the originals.
    $self->{acl}    = undef;
    $self->{xtdc}   = undef;

}

=head2 setup

Begin the transaction.

=cut

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_begin;

}

=head2 teardown

Rollback the transaction.

=cut

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
    $self->schema->operator_id( undef );

}

=head2 test_update_order_status

The scenarios in this test use the following methods:
    test_update_order_status_TEST

=cut

sub test_update_order_status : Tests {
    my $self = shift;

    my ( $pre_order, $order )   = Test::XTracker::Data::PreOrder->create_part_exported_pre_order;
    my $invalid_order_id        = $self->schema->resultset('Public::Orders')->get_column('id')->max + 1;
    my $shipment                = $order->get_standard_class_shipment;
    my $setup_prepaid_order     = sub { $shipment->set_status_hold( $APPLICATION_OPERATOR_ID, $SHIPMENT_HOLD_REASON__PREPAID_ORDER, 'Test' ) };
    my $setup_other             = sub { $shipment->set_status_hold( $APPLICATION_OPERATOR_ID, $SHIPMENT_HOLD_REASON__OTHER, 'Test' ) };

    $self->test_scenarios({
        'No Payload' => {
            setup               => $setup_prepaid_order,
            has_permission      => 1,
            request_data        => [],
            shipment_changed    => 0,
            expected_code       => 400,
        },
        'Empty Payload' => {
            setup               => $setup_prepaid_order,
            has_permission      => 1,
            request_data        => [ {} ],
            shipment_changed    => 0,
            expected_code       => 400,
            expected_response   => {
                error => 'Missing order ID',
            },
        },
        'Non-Numeric Order ID' => {
            setup               => $setup_prepaid_order,
            has_permission      => 1,
            request_data        => [ { order_id => 'BAD' } ],
            shipment_changed    => 0,
            expected_code       => 400,
            expected_response   => {
                error => 'Invalid order ID',
            },
        },
        'Non-Existent Order ID' => {
            setup               => $setup_prepaid_order,
            has_permission      => 1,
            request_data        => [ { order_id => $invalid_order_id } ],
            shipment_changed    => 0,
            expected_code       => 400,
            expected_response   => {
                error => "Order ID $invalid_order_id does not exist",
            },
        },
        'Valid Order ID (On Pre-Order Hold)' => {
            setup               => $setup_prepaid_order,
            has_permission      => 1,
            request_data        => [ { order_id => $order->id } ],
            shipment_changed    => 1,
            expected_code       => 200,
            expected_response   => {
                status => 'SUCCESS',
            },
        },
        'Valid Order ID (Not On Pre-Order Hold)' => {
            setup               => $setup_other,
            has_permission      => 1,
            request_data        => [ { order_id => $order->id } ],
            shipment_changed    => 0,
            expected_code       => 400,
            expected_response   => {
                error => 'Order ' . $order->order_nr . ' is not on Pre-Order hold and cannot be released',
            },
        },
        'Valid Order ID (No Permissions)' => {
            setup               => $setup_prepaid_order,
            has_permission      => 0,
            request_data        => [ { order_id => $order->id } ],
            shipment_changed    => 0,
            expected_code       => 401,
            expected_response   => {
                error => 'Access Denied',
            },
        },
    }, 'Update Order Status',
    { test_args => [ $shipment ] } );

}

=head1 SCENARIO METHODS

=head2 test_update_order_status_TEST

Does the following:
    * Updates the shipment for the Pre-Order to be on Hold as required.
    * Sends the request.
    * Checks the response code is as expected.
    * Checks the response is as expected.
    * Checks whether the shipment status has changed.

=cut

sub test_update_order_status_TEST {
    my $self = shift;
    my ( $test_name, $test_data, $shipment ) = @_;

    $self->{has_permission} = $test_data->{has_permission};

    # Clear all the holds and then call setup, to set the appropriate hold.
    $shipment->shipment_holds->delete;
    $test_data->{setup}->();

    my $response = $self->send_request( $test_data->{expected_code},
        @{ $test_data->{request_data} } );

    cmp_deeply( $response, $test_data->{expected_response}, 'Got the correct response back' )
        if exists $test_data->{expected_response};

    my $shipment_status_id  = $shipment->discard_changes->shipment_status_id;

    $test_data->{shipment_changed}
        ? cmp_ok( $shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING, 'Shipment status has changed to: PROCESSING' )
        : cmp_ok( $shipment_status_id, '==', $SHIPMENT_STATUS__HOLD, 'Shipment status is still: HOLD' );

}

=head1 METHODS

=head2 send_request( $expected_response_code, $payload )

Sends a C<$payload> (encoded as JSON) to the following API endpoint:
    /API/StockControl/Reservation/PreOrder/PreOrderOnhold/UpdateOrderStatus

Checks the response has the C<$expected_response_code>.

Returns the content decoded as JSON.

=cut

sub send_request {
    my $self = shift;
    my ( $expected_response_code, $payload ) = @_;

    $payload        = eval { encode_json( $payload ) };
    my $response    = request POST
        '/API/StockControl/Reservation/PreOrder/PreOrderOnhold/UpdateOrderStatus',
        'Content-Type'      => 'application/json',
        'X-Requested-With'  => 'XMLHttpRequest',
        'Content'           => $payload;

    cmp_ok( $response->code, '==', $expected_response_code,
        "Response is $expected_response_code" );

    return decode_json( $response->content );

}
