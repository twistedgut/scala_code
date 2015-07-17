#!/usr/bin/env perl

use NAP::policy "tt",     qw( class test );

BEGIN {
    extends "NAP::Test::Class";
}

=head1 NAME

credit_hold_and_check_an_order.t - verifies that the "Credit Hold" and
"Credit Check" options on OrderView page function correctly

=head1 DESCRIPTION

This checks the Left Hand Menu Options on the Order View page: 'Credit Hold' &
'Credit Check' to make sure an order and shipment is set to the appropriate
Status. It also tests that the order status is set to 'Accepted' and the shipment
status is set to "Processing" when the order is accepted via the orderview left
hand menu option.

#TAGS orderview finance cando

=cut


use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw (
                                            :authorisation_level
                                            :correspondence_templates
                                            :order_status
                                            :shipment_status
                                            :bulk_order_action
                                        );

use JSON;


sub startup : Test( startup => no_plan ) {
    my $self    = shift;

    $self->SUPER::startup;

    my $framework   = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::CustomerCare',
            'Test::XT::Flow::Finance',
            'Test::XT::Data::Order',
        ],
    );
    $self->{framework} = $framework;
}

sub setup : Test( setup => no_plan ) {

    my $self = shift;
    my $framework = $self->{framework};

    $framework->login_with_roles( {
        names => [ 'app_canProcessCreditHoldCheck' ],
        main_nav => [
            'Customer Care/Order Search',
            'Customer Care/Customer Search',
        ],
        # need this so that you can get to the Order View page
        setup_fallback_perms => 1,
        dept => undef,
    } );

    # create an Order
    my $orddetails  = $framework->new_order(
        channel  => Test::XTracker::Data->channel_for_nap,
        products => 2,
    );
    my $order       = $orddetails->{order_object};
    my $shipment    = $orddetails->{shipment_object};
    my $customer    = $orddetails->{customer_object};

    # remove any email logs
    $order->order_email_logs->delete;
    # set 'credit_check' date to NULL
    $customer->update( { credit_check => undef } );

    $self->{order} = $order;
    $self->{shipment} = $shipment;
    $self->{customer} = $customer;
    $self->{framework} = $framework;
}

=head1 TESTS

=head2 test_credit_hold_credit_check_order

This checks the Left Hand Menu Options on the Order View page: 'Credit Hold' & 'Credit Check' to make sure an
Order is set to the appropriate Status. It also tests that the Order can be 'Accepted' and Shipment is put back
on correct previous Status.

=cut

sub test_credit_hold_credit_check_order : Tests() {
    my $self = shift;

    my $framework = $self->{framework};
    my $order    = $self->{order};
    my $shipment = $self->{shipment};
    my $customer = $self->{customer};

    note "Put Order on Credit Hold";
    $framework->flow_mech__customercare__orderview( $order->id )
                ->flow_mech__customercare__put_on_credit_hold;
    _discard_changes( $order, $shipment, $customer );
    cmp_ok( $order->order_status_id, '==', $ORDER_STATUS__CREDIT_HOLD, "Order Status now 'Credit Hold'" );
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__FINANCE_HOLD, "Shipment Status now 'Finance Hold'" );
    ok( !defined $customer->credit_check, "Customer's 'credit_check' field is still NULL" );
    cmp_ok( $order->order_email_logs->count, '==', 0, "No Emails logged against the Order" );

    note "Accept Order on Credit Hold " .$shipment->id."\n";
    # make up shipment_status_log
    $shipment->shipment_status_logs->delete;
    _create_shipment_logs( $shipment, {
        logs => [
            {
                shipment_status_id  => $SHIPMENT_STATUS__PROCESSING,
                operator_id         => $self->_operator_id(),
                date                => _get_datetime_object('2014','03','03'),
            },
            {
                shipment_status_id  => $SHIPMENT_STATUS__HOLD,
                operator_id         => $self->_operator_id(),
                date                => _get_datetime_object('2014','03','04'),
            }

        ],
    });
    $framework->flow_mech__customercare__accept_order;
    _discard_changes( $order, $shipment, $customer );


    cmp_ok( $order->order_status_id, '==', $ORDER_STATUS__ACCEPTED, "Order Status now 'Accepted'" );
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING, "Shipment Status now 'Processing'" );
    ok( !defined $customer->credit_check, "Customer's 'credit_check' field is still NULL" );
    cmp_ok( $order->order_email_logs->count, '==', 0, "No Emails logged against the Order" );

    note "Put Order on Credit Hold then straight to Credit Check";
    $framework->flow_mech__customercare__put_on_credit_hold
                ->flow_mech__customercare__put_on_credit_check;
    _discard_changes( $order, $shipment, $customer );
    cmp_ok( $order->order_status_id, '==', $ORDER_STATUS__CREDIT_CHECK, "Order Status now 'Credit Check'" );
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__FINANCE_HOLD, "Shipment Status now 'Finance Hold'" );
    ok( !defined $customer->credit_check, "Customer's 'credit_check' field is still NULL" );
    cmp_ok( $order->order_email_logs->count, '==', 0, 'No Email logged');

    note "Accept Order on Credit Check";
    # delete all log entries
    $shipment->shipment_status_logs->delete;
    _create_shipment_logs( $shipment, {
        logs => [
            {
                shipment_status_id  => $SHIPMENT_STATUS__DISPATCHED,
                operator_id         => $self->_operator_id(),
                date                => _get_datetime_object('2014','03','03'),
            },
            {
                shipment_status_id  => $SHIPMENT_STATUS__FINANCE_HOLD,
                operator_id         => $self->_operator_id(),
                date                => _get_datetime_object('2014','03','04'),
            },
            {
                shipment_status_id  => $SHIPMENT_STATUS__FINANCE_HOLD,
                operator_id         => $self->_operator_id(),
                date                => _get_datetime_object('2014','03','05'),
            }

        ],
    });

    $framework->flow_mech__customercare__accept_order;
    _discard_changes( $order, $shipment, $customer );
    cmp_ok( $order->order_status_id, '==', $ORDER_STATUS__ACCEPTED, "Order Status now 'Accepted'" );
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DISPATCHED, "Shipment Status now 'Dispatched'");
    ok( defined $customer->credit_check, "Customer's 'credit_check' field is now populated" );
    cmp_ok( $order->order_email_logs->count, '==', 0, "No More Emails logged against the Order" );


    note "Put Order back  on Credit hold-> Credit Check-> Accept order Loop ";
    $framework->flow_mech__customercare__put_on_credit_hold
                ->flow_mech__customercare__put_on_credit_check;

    _discard_changes( $order, $shipment, $customer );
    # delete all shipment_status_log entries
    $shipment->shipment_status_logs->delete;

    $framework->flow_mech__customercare__accept_order;
    _discard_changes( $order, $shipment, $customer );
    cmp_ok( $order->order_status_id, '==', $ORDER_STATUS__ACCEPTED, "Order Status now 'Accepted'" );
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING, "Shipment Status now 'Processing'");

}

=head2 test_acl_credit_hold_credit_check_order

This checks the Left Hand Menu Options on the Order View page: 'Credit Hold', 'Credit Check'
and 'Accept Order' to make sure they are available and usable only when the Operator has the
correct ACL Roles.

=cut

sub test_acl_credit_hold_credit_check_order : Tests() {

    my $self = shift;

    my $framework = $self->{framework};
    my $mech      = $framework->mech;

    my $order    = $self->{order};
    my $shipment = $self->{shipment};
    my $customer = $self->{customer};

    $framework->login_with_roles( {
        names => [ ],
        main_nav => [
            'Customer Care/Order Search',
            'Customer Care/Customer Search',
        ],
        setup_fallback_perms => 1,
        dept => undef,
    } );
    my $session = $mech->session;


    note "Check for Credit Hold";
    $framework->flow_mech__customercare__orderview( $order->id );
    $mech->hasnt_sidenav_options( [ 'Credit Hold', 'Credit Check', 'Accept Order' ],
                    "Sidenav Options aren't present when Operator doesn't have Role" );

    $session->add_acl_roles( ['app_canProcessCreditHoldCheck'] );
    $framework->flow_mech__customercare__orderview( $order->id );
    $mech->has_sidenav_options( [ 'Credit Hold' ], "Found Sidenav Option when Operator has Role" );
    $mech->hasnt_sidenav_options( [ 'Credit Check', 'Accept Order' ],
                    "Sidenav Options not present when Order not in correct State" );

    $session->remove_acl_roles( ['app_canProcessCreditHoldCheck'] );
    $framework->test_for_no_permissions(
        "Can't use 'Credit Hold' without correct Role",
        'flow_mech__customercare__put_on_credit_hold'
    );

    note "should be-able to use 'Credit Hold' with correct Role";
    $session->add_acl_roles( ['app_canProcessCreditHoldCheck'] );
    $framework->flow_mech__customercare__orderview( $order->id )
                ->flow_mech__customercare__put_on_credit_hold;
    $mech->has_sidenav_options( [ 'Credit Check', 'Accept Order' ],
                    "Sidenav Options present when Order in correct State" );
    $mech->hasnt_sidenav_options( [ 'Credit Hold' ], "Sidenav Option not Present when Order in correct state" );


    note "Check for Credit Check";
    $session->remove_acl_roles( ['app_canProcessCreditHoldCheck'] );
    $framework->flow_mech__customercare__orderview( $order->id );
    $mech->hasnt_sidenav_options( [ 'Credit Hold', 'Credit Check', 'Accept Order' ],
                    "Sidenav Options aren't present when Operator doesn't have Role" );

    $session->add_acl_roles( ['app_canProcessCreditHoldCheck'] );
    $framework->flow_mech__customercare__orderview( $order->id );
    $session->remove_acl_roles( ['app_canProcessCreditHoldCheck'] );
    $framework->test_for_no_permissions(
        "Can't use 'Credit Check' without correct Role",
        'flow_mech__customercare__put_on_credit_check',
    );

    note "should be-able to use 'Credit Check' with correct Role";
    $session->add_acl_roles( ['app_canProcessCreditHoldCheck'] );
    $framework->flow_mech__customercare__orderview( $order->id )
                ->flow_mech__customercare__put_on_credit_check;
    $mech->has_sidenav_options( [ 'Accept Order' ],
                    "Sidenav Option present when Order in correct State" );
    $mech->hasnt_sidenav_options( [ 'Credit Hold', 'Credit Check' ], "Sidenav Options not Present when Order in correct state" );


    note "Check for Accept Order";
    $session->remove_acl_roles( ['app_canProcessCreditHoldCheck'] );
    $framework->flow_mech__customercare__orderview( $order->id );
    $mech->hasnt_sidenav_options( [ 'Credit Hold', 'Credit Check', 'Accept Order' ],
                    "Sidenav Options aren't present when Operator doesn't have Role" );

    $session->add_acl_roles( ['app_canProcessCreditHoldCheck'] );
    $framework->flow_mech__customercare__orderview( $order->id );
    $session->remove_acl_roles( ['app_canProcessCreditHoldCheck'] );
    $framework->test_for_no_permissions(
        "Can't use 'Accept Order' without correct Role",
        'flow_mech__customercare__accept_order',
    );

    note "should be-able to use 'Accept Order' with correct Role";
    $session->add_acl_roles( ['app_canProcessCreditHoldCheck'] );
    $framework->flow_mech__customercare__orderview( $order->id )
                ->flow_mech__customercare__accept_order;
}

=head2 test_credit_check_page_acl_protection

Test the ACL Protection implemented for Credit Check page

=cut

sub test_credit_check_page_acl_protection : Tests() {
    my $self    = shift;

    my $framework = $self->{framework};

    # start with NO Roles
    $framework->login_with_roles( {
        # make sure Department is 'undef' as it
        # shouldn't be required for this page
        dept => undef,
    } );

    $framework->test_for_no_permissions(
        "can't access 'Finance->Credit Check'",
        flow_mech__finance__credit_check => ()
    );

    note "set Roles";
    $self->mech->set_session_roles( '/Finance/CreditCheck' );

    $framework->flow_mech__finance__credit_check;
    $self->mech->has_sidenav_options( [ 'Key to Icons' ] );
}

=head2 test_credit_hold_page_acl_protection

Test the ACL Protection implemented for Credit Hold page

=cut

sub test_credit_hold_page_acl_protection : Tests() {
    my $self    = shift;

    my $framework = $self->{framework};

    my $order    = $self->{order};
    my $shipment = $self->{shipment};
    $order->update( { order_status_id => $ORDER_STATUS__CREDIT_HOLD } );
    $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__FINANCE_HOLD } );

    my $channel_conf = $order->channel->business->config_section;

    # start with NO Roles
    $framework->login_with_roles( {
        # make sure Department is 'undef' as it
        # shouldn't be required for this page
        dept => undef,
    } );

    $framework->test_for_no_permissions(
        "can't access 'Finance->Credit Hold'",
        flow_mech__finance__credit_hold => ()
    );

    note "set Roles to view Credit Hold page, but NOT to Bulk Release";
    $self->mech->set_session_roles( '/Finance/CreditHold' );

    $framework->flow_mech__finance__credit_hold;
    my $pg_data = $self->pg_data->{credit_hold}{ $channel_conf };
    my $row     = $pg_data->{credit_hold_list}[0];
    isa_ok( $row, 'HASH', "Found a Row of data in the table" );
    ok( !$row->{Release}, "and there is NO Release checkbox option for the Row" );
    ok( !$pg_data->{release_button}, "and the 'Release' button is NOT shown" );
    $self->mech->has_sidenav_options( [ 'Key to Icons' ] );
    $self->mech->hasnt_sidenav_options( [ 'View Bulk Action Log' ] );

    $framework->test_for_no_permissions(
        "can't access 'View Bulk Action Log'",
        flow_mech__finance__credit_hold__view_bulk_action_log => ()
    );

    # this is called using AJAX & returns JSON so can't go through the Flow methods
    my $bulk_action_log_url = '/Finance/CreditHold/BulkOrderActionLog?action_id=' . $BULK_ORDER_ACTION__CREDIT_HOLD_TO_ACCEPT;
    $self->mech->get_ok( $bulk_action_log_url );
    like( $self->mech->content, qr/don't have permission to/i,
                        "No Permission to call '/Finance/CreditHold/BulkOrderActionLog'" );

    note "now Grant Roles to Bulk Release";
    $self->mech->set_session_roles( [ qw( /Finance/CreditHold /Finance/CreditHold/ViewBulkActionLog ) ] );

    $framework->flow_mech__finance__credit_hold;
    $pg_data = $self->pg_data->{credit_hold}{ $channel_conf };
    $row     = $pg_data->{credit_hold_list}[0];
    ok( $row->{Release}, "CAN now see the Release checkbox option for a Row" );
    ok( $pg_data->{release_button}, "and the 'Release' button is SHOWN" );
    $self->mech->has_sidenav_options( [ 'Key to Icons', 'View Bulk Action Log' ] );

    $framework->flow_mech__finance__credit_hold__view_bulk_action_log;
    $self->mech->has_sidenav_options( [ 'Back to Credit Hold' ] );

    $self->mech->get_ok( $bulk_action_log_url );
    my $got = JSON->new->decode( $self->mech->content );
    cmp_ok( $got->{ok}, '==', 1, "Can now call '/Finance/CreditHold/BulkOrderActionLog'" );
}

#-----------------------------------------------------------------

sub _discard_changes {
    my @recs    = @_;
    $_->discard_changes     foreach ( @recs );
    return;
}

sub mech {
    my $self = shift;
    return $self->{framework}->mech;
}

sub pg_data {
    my $self = shift;
    return $self->mech->as_data;
}

sub _create_shipment_logs {
    my $shipment = shift;
    my $args     = shift;


    for my $log_def (@{$args->{logs}}) {
        $shipment->create_related('shipment_status_logs', $log_def);
    }

}

sub _operator_id {
    return Test::XTracker::Data->get_application_operator_id()
}

sub _get_datetime_object {
    my ($year, $month, $day ) = @_;

    return DateTime->new(
         year    => $year,
         month   => $month,
         day     => $day,
    );
}

Test::Class->runtests;
