#!/usr/bin/env perl
use NAP::policy qw( test class );
BEGIN { extends "NAP::Test::Class" }

use Test::XT::Flow;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Data::Operator;

use XTracker::Constants::FromDB qw(
    :authorisation_level
    :shipment_hold_reason
);

=head1 NAME

t/30-functional/cando/customercare/reservation_pre_orders_on_hold.t

=head1 DESCRIPTION

Tests the 'Pre-Orders on Hold' page, under Stock Control -> Reservations.

=head1 TESTS

=head2 test_startup

Create two new Pre-Orders assigned to two new Operators.

Each Pre-Order is created with two orders, to ensure the rows are not
duplicated.

=cut

sub test_startup : Test( startup => no_plan ) {
    my $self = shift;

    use_ok('XT::DC::Controller::PreOrder::BulkRelease');

    ( $self->{operator_1}, $self->{operator_2} )    = map { Test::XTracker::Data::Operator->create_new_operator } 1..2;
    my ( $pre_order_1, @pre_order_1_orders )        = Test::XTracker::Data::PreOrder->create_part_exported_pre_order({ order_item_counts => [ 2, 2 ] });
    my ( $pre_order_2, @pre_order_2_orders )        = Test::XTracker::Data::PreOrder->create_part_exported_pre_order({ order_item_counts => [ 2, 2 ] });

    $self->{pre_orders} = [{
        pre_order   => $pre_order_1,
        orders      => \@pre_order_1_orders,
    },{
        pre_order   => $pre_order_2,
        orders      => \@pre_order_2_orders,
    }];

    $self->{pre_orders}->[0]->{pre_order}->update({ operator_id => $self->{operator_1}->id });
    $self->{pre_orders}->[1]->{pre_order}->update({ operator_id => $self->{operator_2}->id });

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Reservations',
        ],
    );

}

=head2 test_permission_failure

Test that with the wrong permissions we cannot access the page.

=cut

sub test_permission_failure : Tests {
    my $self = shift;

    $self->{framework}->login_with_permissions( {
        perms => {
            $AUTHORISATION_LEVEL__OPERATOR => [
                'Admin/User Admin',
            ],
        },
    } );

    $self->{framework}->catch_error(
        qr/You don't have permission to access Reservation in Stock Control/,
        'Cannot see Pre-Order on hold Page without correct permisions',
        'mech__reservation__pre_orders_on_hold' );

}

=head2 test_pre_order_visibility

Test that under the following conditions, the page shows the correct
Pre-Orders and checkboxes:

Only Pre-Order 2 is Visible, Operator 1 Cannot See Anything
    Set pre-order1 to be NOT on hold.
    Set pre-order2 to be ON (Pre-Order) HOLD.
    Fetch the page.
    Check nothing is displayed.

Both Pre-Orders are Visible - Operator 1 Can Only See Pre-Order 1, Pre-Order 1 Checkbox is Visible
    Set pre-order1 to be ON (Pre-Order) HOLD.
    Set pre-order2 to be ON (Pre-Order) HOLD.
    Fetch the page.
    Check ONLY pre-order1 is shown.
    CheckEnsure checkbox is present.

Only Pre-Order 1 is Visible, Operator 2 Cannot See Anything
    Set pre-order1 to be ON (Pre-Order) HOLD.
    Set pre-order2 to be NOT on hold.
    Submit the operator form as operator2.
    Check nothing is displayed.

Both Pre-Orders are Visible - Operator 2 Can Only See Pre-Order 2, Pre-Order 2 Checkbox is Visible
    Set pre-order1 to be ON (Pre-Order) HOLD.
    Set pre-order2 to be ON (Pre-Order) HOLD.
    Submit the operator form as operator2.
    Check ONLY pre-order2 is shown.
    CheckEnsure checkbox is present.

Only Pre-Order 1 is Visible, Operator 1 Can Only See Pre-Order 1, Pre-Order 1 Checkbox is NOT Visible
    Set pre-order1 to be ON (Non Pre-Order) HOLD.
    Set pre-order2 to be NOT on hold.
    Fetch the page.
    Check ONLY pre-order1 is shown.
    CheckEnsure checkbox is NOT present.

=cut

sub test_pre_order_visibility : Tests {
    my $self = shift;

    $self->{framework}->login_with_permissions( {
        auth => {
            user    => $self->{operator_1}->username,
            passwd  => $self->{operator_1}->password,
        },
    } );

    $self->{framework}->mech->grant_permissions(
        $self->{operator_1}->id,
        'Stock Control',
        'Reservation',
        $AUTHORISATION_LEVEL__OPERATOR );

    my $pre_order_1 = $self->{pre_orders}->[0];
    my $pre_order_2 = $self->{pre_orders}->[1];

    $self->test_scenarios({
        'Only Pre-Order 2 is Visible, Operator 1 Cannot See Anything' => {
            using_operator      => undef,
            expected            => [],
            pre_order_status    => [
                sub { shift->set_status_processing( $self->{operator_1}->id ) },
                sub { shift->set_status_hold( $self->{operator_1}->id, $SHIPMENT_HOLD_REASON__PREPAID_ORDER, 'Test' ) },
            ],
        },
        'Both Pre-Orders are Visible - Operator 1 Can Only See Pre-Order 1, Pre-Order 1 Checkbox is Visible' => {
            using_operator      => undef,
            expected            => [
                $self->format_pre_order( $pre_order_1->{pre_order}, $pre_order_1->{orders}->[0], 1 ),
                $self->format_pre_order( $pre_order_1->{pre_order}, $pre_order_1->{orders}->[1], 1 ),
            ],
            pre_order_status    => [
                sub { shift->set_status_hold( $self->{operator_1}->id, $SHIPMENT_HOLD_REASON__PREPAID_ORDER, 'Test' ) },
                sub { shift->set_status_hold( $self->{operator_1}->id, $SHIPMENT_HOLD_REASON__PREPAID_ORDER, 'Test' ) },
            ],
        },
        'Only Pre-Order 1 is Visible, Operator 2 Cannot See Anything' => {
            using_operator      => $self->{operator_2},
            expected            => [],
            pre_order_status    => [
                sub { shift->set_status_hold( $self->{operator_2}->id, $SHIPMENT_HOLD_REASON__PREPAID_ORDER, 'Test' ) },
                sub { shift->set_status_processing( $self->{operator_2}->id ) },
            ],
        },
        'Both Pre-Orders are Visible - Operator 2 Can Only See Pre-Order 2, Pre-Order 2 Checkbox is Visible' => {
            using_operator      => $self->{operator_2},
            expected            => [
                $self->format_pre_order( $pre_order_2->{pre_order}, $pre_order_2->{orders}->[0], 1 ),
                $self->format_pre_order( $pre_order_2->{pre_order}, $pre_order_2->{orders}->[1], 1 ),
            ],
            pre_order_status    => [
                sub { shift->set_status_hold( $self->{operator_2}->id, $SHIPMENT_HOLD_REASON__PREPAID_ORDER, 'Test' ) },
                sub { shift->set_status_hold( $self->{operator_2}->id, $SHIPMENT_HOLD_REASON__PREPAID_ORDER, 'Test' ) },
            ],
        },
        'Only Pre-Order 1 is Visible, Operator 2 Cannot See Anything, Pre-Order 1 Checkbox is NOT Visible' => {
            using_operator      => undef,
            expected            => [
                $self->format_pre_order( $pre_order_1->{pre_order}, $pre_order_1->{orders}->[0], 0 ),
                $self->format_pre_order( $pre_order_1->{pre_order}, $pre_order_1->{orders}->[1], 0 ),
            ],
            pre_order_status    => [
                sub { shift->set_status_hold( $self->{operator_2}->id, $SHIPMENT_HOLD_REASON__OTHER, 'Test' ) },
                sub { shift->set_status_processing( $self->{operator_1}->id ) },
            ],
        },
    }, 'Pre-Order Visibility' );

}

=head1 SCENARIO METHODS

=head2 test_pre_order_visibility_TEST

Run the tests for C<test_pre_order_visibility>.

=cut

sub test_pre_order_visibility_TEST {
    my $self = shift;
    my ( $test_name, $test_data ) = @_;

    foreach my $pre_order ( @{ $self->{pre_orders} } ) {
        my $pre_order_update = shift @{ $test_data->{pre_order_status} };
        foreach my $order ( @{ $pre_order->{orders} } ) {

            # Remove the previous hold reasons left from the last test.
            $order->get_standard_class_shipment->shipment_holds->delete;

            # Update the status of the Pre-Order.
            $pre_order_update->( $order->get_standard_class_shipment );

        }
    }

    # Get the Pre-Orders on Hold page.
    $self->{framework}->mech__reservation__pre_orders_on_hold;
    $self->{framework}->mech->no_feedback_error_ok;

    # If we're using a different operator, submit the form to change to that
    # operator.
    if ( $test_data->{using_operator} ) {
        $self->{framework}->mech__reservation__pre_orders_on_hold__operator_submit({
            alt_operator_id => $test_data->{using_operator}->id });
        $self->{framework}->mech->no_feedback_error_ok;
    }

    $test_data->{expected} = [ map { $_->() } @{ $test_data->{expected} } ];

    cmp_deeply( $self->{framework}->mech->as_data->{pre_order_list},
        $test_data->{expected}, 'The list of Pre-Orders is correct' );

}

=head2 format_pre_order( $pre_order, $order, $checkbox_present )

Returns a data structure suitable for use in comparison with data returned
from the Test Client.

=cut

sub format_pre_order {
    my $self = shift;
    my ( $pre_order, $order, $checkbox_present ) = @_;

    return sub { return {
        'Order'         => {
            url     => '/CustomerCare/OrderSearch/OrderView?order_id=' . $order->id,
            value   => $order->order_nr,
        },
        'PreOrder'      => {
            url     => '/StockControl/Reservation/PreOrder/Summary?pre_order_id=' . $pre_order->id,
            value   => 'P' . $pre_order->id,
        },
        'Customer'          => {
            url     => '/CustomerCare/OrderSearch/CustomerView?customer_id=' . $pre_order->customer->id,
            value   => $pre_order->customer->display_name,
        },
        'Total Value'       => $pre_order->total_value,
        'Pre-Order Status'  => 'Part Exported',
        'Hold Reason'       => $order->get_standard_class_shipment->shipment_general_hold_description,
        'Date'              => $pre_order->created->dmy,
        'SELECT_ALL'        => ( $checkbox_present ? superhashof( { input_name => 'order_' . $order->id } ) : '' ),
        'RESULT'            => '',
    } };

}

Test::Class->runtests;
