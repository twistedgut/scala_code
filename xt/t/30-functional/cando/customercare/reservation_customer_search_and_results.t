#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 NAME

reservation_customer_search_and_results.t - Reservation Customer Search & Results

=head1 DESCRIPTION

This will test Searching for a Customer on the Reservation pages and getting to
the Customer's list of Reservations & Pre-Orders.

This page is reached via the 'Stock Control->Reservation' Page and the
'Customer' Left Hand Menu option under the 'Search' heading.

It currently tests:
    * Which departments can see the 'Create Pre-Order' button
    * When Pre-Order is turned Off system wide then the 'Create Pre-Order'
        button is not shown

#TAGS inventory reservation preorder cando

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XT::Flow;

use XTracker::Constants::FromDB         qw(
                                            :authorisation_level
                                            :department
                                        );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "Sanity check" );

#-------------------------------------------------
test_create_pre_order_permission( $schema, 1 );
#-------------------------------------------------

done_testing();


=head1 METHODS

=head2 test_create_pre_order_permission

    test_create_pre_order_permission( $schema, $ok_to_do_flag );

Tests that the operators in the 'Fashion Advisors' and 'Personal Shopping' departments can only see the
'Create Pre-Order' button on the Customer Reservations page.

=cut

sub test_create_pre_order_permission {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip 'test_create_pre_order_permission', 1     if ( !$oktodo );

        note "Test Which Departments can see the Create Pre-Order button";

        my $framework = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Flow::Reservations',
                'Test::XT::Flow::Fulfilment',
                'Test::XT::Data::Channel',
                'Test::XT::Data::Customer',
            ],
        );
        my $channel     = $framework->mech->channel( $framework->channel );

        # create an Order before creating a Customer so I get 2
        # Customers created which I can use in later tests
        my $orddetails  = $framework->flow_db__fulfilment__create_order(
            channel  => $channel,
        );
        my $order   = $orddetails->{order_object};

        # now create a new Customer to use in the tests
        my $customer    = $framework->customer;
        my $mech        = $framework->mech;
        my $customer_nr = $customer->is_customer_number;

        # turn On Pre-Orders for the Sales Channel
        my $orig_pre_order_state    = Test::XTracker::Data::PreOrder->set_pre_order_active_state_for_channel( $channel, 1 );

        # update the Order to the new Customer, as only
        # customers who have placed Orders can use Pre-Order
        my $orig_customer   = $order->customer;
        $order->update( { customer_id => $customer->id } );


        # get Departments which CAN see the button and those that CAN'T
        my %depts           = map { $_->id => $_ } $schema->resultset('Public::Department')->all;
        my @allow_depts     = map { delete $depts{ $_ } } (
                                                                $DEPARTMENT__PERSONAL_SHOPPING,
                                                                $DEPARTMENT__FASHION_ADVISOR,
                                                            );
        my @not_allow_depts = values %depts;


        my $operator    = Test::XTracker::Data->set_department( 'it.god', 'Personal Shopping' );
        $framework->login_with_permissions( {
            perms => {
                    $AUTHORISATION_LEVEL__MANAGER => [
                        'Stock Control/Reservation',
                    ]
                }
            } );


        # get to the Customer's Reservation list page
        $framework->mech__reservation__customer_search
                    ->mech__reservation__customer_search_submit( { customer_number => $customer_nr } )
                        ->mech__reservation__customer_search_results_click_on_customer( $customer_nr );


        note "Check Departments that CAN'T Create Pre-Orders don't see the Button";
        my $expected_buttons    = {
                        multi_reservation   => { found => 1 },      # they should be-able to Create Multi Reservations
                    };
        foreach my $dept ( @not_allow_depts ) {
            note "Department: " . $dept->department;
            $operator->update( { department_id => $dept->id } );
            $mech->reload;
            my $buttons = $mech->as_data()->{create_buttons};
            is_deeply( $buttons, $expected_buttons, "Create Multi-Reservation SHOWN, Create Pre-Order NOT Shown" );
        }

        note "Check Departments that CAN Create Pre-Orders do see the Button";
        $expected_buttons   = {
                        multi_reservation   => { found => 1 },
                        pre_order           => { found => 1 },
                    };
        foreach my $dept ( @allow_depts ) {
            note "Department: " . $dept->department;
            $operator->update( { department_id => $dept->id } );
            $mech->reload;
            my $buttons = $mech->as_data()->{create_buttons};
            is_deeply( $buttons, $expected_buttons, "Create Multi-Reservation SHOWN, Create Pre-Order SHOWN" );
        }


        note "Check when Pre-Order is Disabled for a Sales Channel can't see the Button";
        Test::XTracker::Data::PreOrder->set_pre_order_active_state_for_channel( $channel, 0 );
        delete $expected_buttons->{pre_order};

        $mech->reload;
        my $buttons = $mech->as_data()->{create_buttons};
        is_deeply( $buttons, $expected_buttons, "Create Multi-Reservation SHOWN, Create Pre-Order NOT Shown" );
        Test::XTracker::Data::PreOrder->set_pre_order_active_state_for_channel( $channel, 1 );


        # restore Original Pre-Order state on Sales Channel
        Test::XTracker::Data::PreOrder->set_pre_order_active_state_for_channel( $channel, $orig_pre_order_state );
    };

    return;
}

#---------------------------------------------------------------------------
