#!/usr/bin/env perl

use NAP::policy 'test';
use base 'Test::Class';

=head1 NAME

pre_order_payment.t

=head1 DESCRIPTION

Tests the StockControl/Reservation/PreOrder/Summary page for Finance related data

#TAGS pre_order payment finance cando

=head1 TESTS

=cut

use Data::Dump  qw( pp );

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XT::Flow;


sub setup : Test( setup => no_plan ) {
    my $self = shift;

    $self->{framework}  = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Reservations',

        ],
    );

    Test::XTracker::Data->set_department( 'it.god', 'Customer Care' );

}

=head2 test_pre_order_summary_page

Verifies Payment Card detail is shown on PreOrder Summary page when user have correct
role assigned.

=cut

sub test_pre_order_summary_page : Tests() {
    my $self = shift;

    my $framework = $self->{framework};
    my $mech      = $framework->mech;

    #create a Pre-Order
    my $pre_order       = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
        product_quantity        => 5,
        variants_per_product    => 5,
    } );

    my $pre_order_id = $pre_order->id;
    $mech->clear_session;

    note "Test payment details section is not shown without correct roles";

    $framework->login_with_permissions( {
        roles => {
            names => ['app_canViewProductReservations']
        }
    } );

    my $session = $mech->session->get_session;
    $framework->mech__reservation__pre_order_summary( $pre_order_id );

    my $pg_data = $mech->as_data;

    ok(! exists $pg_data->{'payment_details'},
        "PreOrder Summary page does not have payment related data " );


    note "Test payment details section is not shown  with correct roles";

    $mech->session->replace_acl_roles([
        qw (
            app_canViewProductReservations
            app_canViewOrderPaymentDetails
        )
    ] );

    $framework->mech__reservation__pre_order_summary( $pre_order_id );
    $pg_data = $mech->as_data;

    ok( exists $pg_data->{'payment_details'},
        "PreOrder Summary page have payment related data " );

}

Test::Class->runtests;
