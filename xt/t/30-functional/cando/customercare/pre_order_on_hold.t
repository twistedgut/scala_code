#!/usr/bin/env perl

use NAP::policy "tt",     'test';

use parent "NAP::Test::Class";


use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XT::Flow;

use XTracker::Utilities                 qw( format_currency_2dp );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw (
    :authorisation_level
    :shipment_hold_reason
    :shipment_status
);

sub start_tests :Test( startup => no_plan ) {
    my ($self) = @_;

    $self->{schema} = Test::XTracker::Data->get_schema();

}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    my $mech = Test::XTracker::Mechanize->new;
    $self->{framework}   = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Fulfilment',
            'Test::XT::Flow::CustomerCare',
            'Test::XT::Data::Customer',
            'Test::XT::Data::Channel',

        ],
        mech => $mech,
    );

    $self->{framework}->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                    'Customer Care/Order Search',
                    'Stock Control/Reservation',
                ]
            }
        } );
}

=head1 METHODS

=head2 test_releasing_shipping_restricted_pre_order_order

Checks to see shipping restricted  order linked to pre-order is not released from hold.

=cut

sub test_releasing_shipping_restricted_pre_order_order : Tests() {
    my $self = shift;

    my $op_id       = $APPLICATION_OPERATOR_ID;
    my $order       = Test::XTracker::Data::PreOrder->create_order_linked_to_pre_order();
    my $shipment    = $order->get_standard_class_shipment;
    my @items       = $shipment->shipment_items->search( {}, { order_by => 'id' } )->all;
    my @item_ids    = map { $_->id } @items;


    # Put shipment on hold
    $shipment->hold_for_prepaid_reason({
        operator_id => $op_id
    });

    $self->{framework}->flow_mech__customercare__orderview( $order->id );

    is( $self->{framework}->mech->as_data->{'meta_data'}->{'Shipment Details'}->{'Status'},
            'Hold', 'Shipment was placed on hold' );

    # Test 1: Releasing a shipment which is on hold (reason: pre-paid order) which does not have restricted products
    # should be fine.
    $self->{framework}->flow_mech__customercare__hold_shipment()
                       ->flow_mech__customercare__hold_release_shipment();

    is( $self->{framework}->mech->as_data->{'meta_data'}->{'Shipment Details'}->{'Status'},
            'Processing', 'Shipment was successfully released from hold' );


    # Test 2: Releasing a shipment which is on hold (reason: anything but not pre-paid order) and
    # does not have restricted product should be fine too.

    # Put shipment on hold
    $shipment->put_on_hold({
        operator_id => $op_id,
        status_id   => $SHIPMENT_STATUS__HOLD,
        norelease   => 1,
        reason      => $SHIPMENT_HOLD_REASON__STOCK_DISCREPANCY,
    });


    # make the product restricted
    my $shipping_restriction = Test::XT::Rules::Solve->solve( 'Shipment::restrictions', {
        restriction => 'CHINESE_ORIGIN',
    } );
    my $shipping_address    = $order->get_standard_class_shipment->shipment_address;

    $shipping_address->update( { country => $shipping_restriction->{address}{country} } );

    my $item = $shipment->shipment_items->first;
    $item->variant->product->shipping_attribute->update( $shipping_restriction->{shipping_attribute} );

    # Release shipment
    $self->{framework}->flow_mech__customercare__hold_shipment()
                       ->flow_mech__customercare__hold_release_shipment();

    is( $self->{framework}->mech->as_data->{'meta_data'}->{'Shipment Details'}->{'Status'},
            'Processing', 'Shipment was successfully released from hold' );

    # Test 3 : Releasing a shipment which is on hold (reason: pre_paid order) and has restricted product should give an error

    # Put shipment on hold
    $shipment->hold_for_prepaid_reason({
        operator_id => $op_id
    });

    $self->{framework}->flow_mech__customercare__hold_shipment();

    $self->{framework}->errors_are_fatal(0);
    $self->{framework}->flow_mech__customercare__hold_release_shipment();
    $self->{framework}->errors_are_fatal(1);


    like( $self->{framework}->mech->app_error_message,
     qr/Cannot release shipment, order contains restricted products which cannot be delivered/,
     "Error meesage is displayed as expected"
    );

}

Test::Class->runtests;
