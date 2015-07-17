#!/usr/bin/env perl

use NAP::policy "tt", qw/test class/;

BEGIN {
    extends "NAP::Test::Class";
};


use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XT::Flow;

use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :customer_category
);



=head1 NAME

pre_order_listing.t - Pre-Order Listing Page ( /StockControl/Reservation/PreOrder/PreOrderList)

=head1 DESCRIPTION

Test the page displays all the columns correctly.

#TAGS preorder cando listing

=cut


sub startup : Test( startup => no_plan ) {
    my $self = shift;

    $self->SUPER::startup;

    $self->{channel}    = Test::XTracker::Data->channel_for_nap;

    $self->{framework}  = Test::XT::Flow->new_with_traits( {
        traits  => [
            'Test::XT::Flow::CustomerCare',
            'Test::XT::Flow::Reservations',
        ]
    });

    $self->{framework}->login_with_permissions( {
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Stock Control/Reservation',
            ],
        },
        dept => 'Personal Shopping',
    } );

    $self->{operator} = $self->{framework}->mech->logged_in_as_object;

    # get another Operator
    $self->{another_operator} = $self->rs('Public::Operator')
        ->search( {
            id => { 'NOT IN' => [ $APPLICATION_OPERATOR_ID, $self->{operator}->id ] },
        } )->first;

}

sub shutdown : Test( shutdown => no_plan ) {
    my $self    = shift;

    $self->SUPER::shutdown;
}

sub setup : Test( setup => no_plan ) {
    my $self    = shift;

    $self->SUPER::setup;

    $self->{products} = Test::XTracker::Data::PreOrder->create_pre_orderable_products();

    $self->{customer} = Test::XTracker::Data->create_dbic_customer( {
        channel_id => $self->{channel}->id,
    } );

}

sub teardown : Test( teardown => no_plan ) {
    my $self    = shift;

    $self->SUPER::teardown;
}


sub test_pre_order_listing_page : Tests() {
    my $self = shift;

    my $past_date =  DateTime->now->subtract( months => 3 );
    my $pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order_for_channel($self->{channel});
    my $alt_pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order_for_channel($self->{channel});
    $alt_pre_order->update( {
        operator_id => $self->{another_operator}->id,
        created     => $past_date
    });
    $pre_order->update( { created => $past_date });


    $self->{framework}->flow_mech__preorder__listing_page();
    my $pg_data = $self->{framework}->mech->as_data->{preorder_list};
    my $key = "preorder__data_". $pre_order->customer_id;

    my %expected_data = (
        'Creation Date' => $past_date->dmy,
        Discount        => "0.00 %",
        PreOrder        => {
            url  => "/StockControl/Reservation/PreOrder/Summary?pre_order_id=".$pre_order->id,
            value =>  "P".$pre_order->id,
        },
       'Reservation Source' => "LookBook",
        Status              => "Complete",
        'Total Value'       => $pre_order->total_value
    );
    # check the preorder with all columns is listed under the logged in user
    is_deeply($pg_data->{$key}[0],\%expected_data,"PreOrder's for logged in operator is listed");


    # choose dropdown to selected alt_operator
    $self->{framework}->flow_mech_preorder_listing__change_operator($self->{another_operator}->id);

    $pg_data = $self->{framework}->mech->as_data->{preorder_list};
    $key = "preorder__data_". $alt_pre_order->customer_id;
    $key = "preorder__data_". $alt_pre_order->customer_id;
    %expected_data = (
        'Creation Date' => $past_date->dmy,
        Discount        => "0.00 %",
        PreOrder        => {
            url     =>    "/StockControl/Reservation/PreOrder/Summary?pre_order_id=".$alt_pre_order->id,
            value   => "P". $alt_pre_order->id,
        },
       'Reservation Source'  => "LookBook",
       Status                => "Complete",
       'Total Value'         => $pre_order->total_value,
    );

    # check preorder is listed for the alternative_operater
    is_deeply($pg_data->{$key}[0],\%expected_data,"PreOrder is displayed correctly for the alternative operator" );

}

Test::Class->runtests;
