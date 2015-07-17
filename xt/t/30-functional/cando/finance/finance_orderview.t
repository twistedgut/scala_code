#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use base 'Test::Class';

=head1 NAME

finance_orderview.t

=head1 DESCRIPTION

Tests the CustomerCare/OrderSearch/OrderView page for Finance related data

#TAGS orderview finance cando

=head1 TESTS

=cut

use Data::Dump  qw( pp );
use DateTime::Duration;

use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Database::Currency        qw( get_currency_glyph );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw (
                                            :authorisation_level
                                        );

sub setup : Test( setup => no_plan ) {
    my $self = shift;

    $self->{framework}  = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::CustomerCare',
            'Test::XT::Flow::Fulfilment',
        ],
    );

    #Finance department.
    Test::XTracker::Data->set_department( 'it.god', 'Finance' );

}

=head2 test_order_paid_by_credit_card

Verifies Payment Card detail is shown on order view page when user have correct
role assigned.

=cut

sub test_order_paid_by_credit_card : Tests() {
    my $self = shift;

    my $framework = $self->{framework};
    my $mech      = $framework->mech;

    # create an Order
    my $orddetails  = $framework->flow_db__fulfilment__create_order_selected(
        channel  => Test::XTracker::Data->channel_for_nap,
        products => 2,
    );
    my $order       = $orddetails->{order_object};
    my $shipment    = $orddetails->{shipment_object};
    my $customer    = $orddetails->{customer_object};

    Test::XTracker::Data->create_payment_for_order( $order , {
        psp_ref     => $order->order_nr,
        preauth_ref => $order->order_nr,
    });

    $mech->get_ok('/Logout');
    $mech->clear_session;

    note "Test payment details section is not shown without correct roles";

    $framework->login_with_permissions( {
        roles => {
            names => [
                'app_canSearchCustomers',
            ]
        },
    } );

    my $session = $mech->session->get_session;
    $framework->flow_mech__customercare__orderview( $order->id );

    my $pg_data = $mech->as_data->{meta_data};

    ok(! exists $pg_data->{'Finance Data'}->{'payment_card_details'},
        "Order does not have payment Cared Details " );

    note " now add appropriate roles ";

    $mech->session->replace_acl_roles([ qw (
        app_canSearchCustomers
        app_canViewOrderPaymentDetails
    ) ] );

    my %expected_fields = (
        'PSP'                         => '',
        'PSP Reference'               => '',
        'Card Number'                 => '',
        'Expiry Date'                 => '',
        'Auth Code'                   => '',
        'Card Type'                   => '',
        'CV2 Check'                   => '',
        '3D Secure Response'          => '',
        'IP Address'                  => '',
        'Stored Card'                 => '',
        'Value'                       => '',
        'Internal Payment Reference'  => '',
        'Valid'                       => '',
        'Fulfilled'                   => '',
        'Issuer'                      => '',
        'Issuing Country'             => '',
        'Payment Attempts'            => '',
        'Payment Method'              => '',
        'Provider'                    => '',
        'Provider Reference'          => '',
        'Current Payment Status'      => '',
        'Original Payment Status'     => '',
    );

    $framework->mech->log_snitch->pause;        # suppress known warning in log thrown because of communication with non-existent PSP
    $framework->flow_mech__customercare__orderview( $order->id );
    $framework->mech->log_snitch->unpause;      # Un-Pause otherwise it will still warn when the test ends

    my $page_data   = $framework->mech->as_data;

    ok( exists( $page_data->{'meta_data'}{'Finance Data'}{'payment_card_details'} ), "'Payment Card Details' are shown in the page" );
    my $payment_data= $page_data->{'meta_data'}{'Finance Data'}{'payment_card_details'};
    is_deeply( [ sort keys %{ $payment_data } ], [ sort keys %expected_fields ], "All expected fields shown in 'Payment Card Details' table" );

}

=head2 test_order_paid_by_store_credit

Verifies Payment Details Store Credit is shown on order view page when user have correct
role assigned.

=cut

sub test_order_paid_by_store_credit : Tests() {
    my $self = shift;

    my $framework = $self->{framework};
    my $mech      = $framework->mech;

    my $order_details = $framework->flow_db__fulfilment__create_order(
        channel  => Test::XTracker::Data->channel_for_nap,
        products => 1,
        create_renumerations => 1,
    );

    my $order = $order_details->{order_object};

    $mech->get_ok('/Logout');
    $mech->clear_session;

    note " Checking Payment Details section is not visible without correct roles";

    $framework->login_with_permissions( {
        roles => {
            names => [ 'app_canSearchCustomers'],
        },
    } );

    my $session = $mech->session->get_session;
    $framework->flow_mech__customercare__orderview( $order->id );

    my $pg_data = $mech->as_data->{meta_data};

    ok(! exists $pg_data->{'Finance Data'}->{'payment_store_credit_details'},
        "Order does not have payment related data " );


    note "With appropriate Role, Store Credit section is visible";

    $mech->session->replace_acl_roles([ qw (
        app_canSearchCustomers
        app_canViewOrderPaymentDetails
    ) ] );

    $framework->flow_mech__customercare__orderview( $order->id );
    $pg_data = $mech->as_data->{meta_data};

    ok(exists $pg_data->{'Finance Data'}->{'payment_store_credit_details'},
        "Order has Store Credit Details " );
}

=head2 test_voucher_usage_history

Verifies Shipment Items shows voucher usage history on order view page when user have correct
role assigned.

=cut

sub test_voucher_usage_history : Tests() {
    my $self = shift;

    my $framework = $self->{framework};
    my $mech      = $framework->mech;

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
        how_many => 1, channel => 'nap',
        phys_vouchers => {
            how_many => 1,
        },
        virt_vouchers => {
            how_many => 1,
        },
    });

     my ($order) = Test::XTracker::Data->apply_db_order({
        pids => [ $pids->[1],$pids->[2] ],
        base => ''
    });


    #create a mixed order
    cmp_ok( $order->contains_a_virtual_voucher, '==', 1, "Mixed Order - Contains Virtual Voucher");
    cmp_ok( $order->contains_a_voucher, '==', 1, "Mixed Order - Contains a Voucher");


    $mech->get_ok('/Logout');
    $mech->clear_session;

    note " Checking Voucher Usage History is not visible without correct roles";

    $framework->login_with_permissions( {
        roles => {
            names => [ 'app_canSearchCustomers'],
        },
    } );

    my $session = $mech->session->get_session;
    $framework->flow_mech__customercare__orderview( $order->id );

    my @data  = @{$mech->as_data->{voucher_usage_history}};

    cmp_ok ( scalar(@data) ,'==', 0 , "Shipment items does not show Voucher Usage history");


    note "With appropriate Role, Voucher Usage History is visible";

    $mech->session->replace_acl_roles([ qw (
        app_canSearchCustomers
        app_canViewOrderPaymentDetails
    ) ] );


    $framework->flow_mech__customercare__orderview( $order->id );
    @data = @{$mech->as_data->{voucher_usage_history}};

    cmp_ok ( scalar(@data) ,'==', 2 , "Shipment items does shows Voucher Usage history");
}


Test::Class->runtests;
