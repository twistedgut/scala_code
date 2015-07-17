#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;

=head1 NAME

multiple_reservations.t - Testing Creating Multiple Reservations for a Customer

=head1 DESCRIPTION

This tests the Multiple Reservation functionality that you get to from the Customer
search left hand menu option from 'Stock Control->Reservation', you then click on
the Customer Number that the search has found and on the next page will show a history
of Reservations/Pre-Orders for the Customer and a button allowing the user to
Create Multiple reservations for a Customer in one hit.

This tests that Multiple Reservations work for MRP, OUTNET & NAP.

#TAGS inventory reservation pws cando

=cut

use Test::XT::Flow;
use Test::XTracker::Data;

use XTracker::Constants::FromDB qw( :authorisation_level :reservation_status );
use XTracker::Constants qw/:application/;


use base 'Test::Class';

=head1 METHODS

=cut

sub startup : Tests(startup) {
    my ($self) = @_;
    $self->{flow} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::MultipleReservations',
        ],
    );
    $self->{schema} = Test::XTracker::Data->get_schema;
}

=head2 create_reservation_on_nap

    $self->create_reservation_on_nap();

Tests Multiple Reservations for NAP.

=cut

sub create_reservation_on_nap : Tests {
    my ($self) = @_;
    my $channel = Test::XTracker::Data->channel_for_nap;
    $self->test_multiple_reservations($channel);
}

=head2 create_reservation_on_mrp

    $self->create_reservation_on_mrp();

Tests Multiple Reservations for MRP.

=cut

sub create_reservation_on_mrp : Tests {
    my ($self) = @_;
    my $channel = Test::XTracker::Data->channel_for_mrp;
    $self->test_multiple_reservations($channel);
}

=head2 create_reservation_on_out

    $self->create_reservation_on_out();

Tests Multiple Reservations for OUTNET.

=cut

sub create_reservation_on_out : Tests {
    my ($self) = @_;
    my $channel = Test::XTracker::Data->channel_for_out;
    $self->test_multiple_reservations($channel);
}

=head2 test_multiple_reservations

    $self->test_multiple_reservations( $dbic_channel );

Test Helper method called by the other functions to test
Multiple Reservations for a given Sales Channel.

=cut

sub test_multiple_reservations {
    my ($self, $channel) = @_;

    my $flow                        = $self->{flow};
    my @pids                        = ();
    my @variants                    = ();
    my $expected_number_of_products = 4;

    # Grab products
    my (undef, $basket) = Test::XTracker::Data->grab_products({
        how_many   => $expected_number_of_products,
        channel_id => $channel->id,
    });

    # Generate list of reservation tokens
    foreach my $product (@{$basket}) {
        push(@pids, $product->{pid});
        push(@variants, $product->{variant_id});
    }

    # Create customer
    my $customer = Test::XTracker::Data->find_or_create_customer({
        channel_id => $channel->id,
    });
    isa_ok($customer, 'XTracker::Schema::Result::Public::Customer');

    Test::XTracker::Data->delete_reservations({
        customer => $customer
    });

    # Login as a specific department.
    $flow->login_with_permissions({
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Stock Control/Reservation',
            ]
        }
    });


    # Test: Without skipping PWS customer check
    $flow->errors_are_fatal(0);
    $flow->mech__multiple_reservation_select({
        customer_id => $customer->id,
    });

    like(
        $flow->mech->app_error_message,
        qr/Customer does not exist on web site/i,
        "Customer does not exist in PWS database"
    );


    # Test: No customer ID
    $flow->errors_are_fatal(0);
    $flow->mech__multiple_reservation_select({
        skip_pws_customer_check => 1,
    });

    like(
        $flow->mech->app_error_message,
        qr/Customer not found/i,
        "No customer id detected"
    );


    # Test: Invalid PID
    my $invalid_pid     = Test::XTracker::Data->get_invalid_product_id();
    my $just_not_a_pid  = '48417484177';
    $flow->errors_are_fatal(0);
    $flow->mech__multiple_reservation_select({
        customer_id             => $customer->id,
        skip_pws_customer_check => 1,
    })->mech__multiple_reservation_select_search({
        pids                    => "${invalid_pid},${just_not_a_pid}",
        skip_pws_customer_check => 1,
    });

    like(
        $flow->mech->app_error_message,
        qr/does not exist in the database/i,
        "Invalid product ID detected for: ${invalid_pid}"
    );
    like(
        $flow->mech->app_error_message,
        qr/is not a valid PID or SKU/i,
        "Not a PID or SKU detected for: ${just_not_a_pid}"
    );

    # Test: Oversided PID length
    $flow->errors_are_fatal(1);
    $flow->mech__multiple_reservation_create({
        customer_id             => $customer->id,
        variants                => [123412345678900],
    });


    # Test: No source ID
    $flow->errors_are_fatal(0);
    $flow->mech__multiple_reservation_select({
        customer_id             => $customer->id,
        skip_pws_customer_check => 1,
    })->mech__multiple_reservation_select_search({
        pids                    => join(',',@pids),
        skip_pws_customer_check => 1,
    })->mech__multiple_reservation_select_reserve({
        variants                => \@variants,
    });

    like(
        $flow->mech->app_error_message,
        qr/No reservation source selected/i,
        "nothing to reserve"
    );


    # Test: No type ID
    $flow->errors_are_fatal(0);
    $flow->mech__multiple_reservation_select({
        customer_id             => $customer->id,
        skip_pws_customer_check => 1,
    })->mech__multiple_reservation_select_search({
        pids                    => join(',',@pids),
        skip_pws_customer_check => 1,
    })->mech__multiple_reservation_select_reserve({
        variants                => \@variants,
        reservation_source_id   => 1,
    });

    like(
        $flow->mech->app_error_message,
        qr/No reservation type selected/i,
        "nothing to reserve"
    );



    # Test: No selected items
    $flow->errors_are_fatal(0);
    $flow->mech__multiple_reservation_select({
        customer_id             => $customer->id,
        skip_pws_customer_check => 1,
    })->mech__multiple_reservation_select_search({
        pids                    => join(',',@pids),
        skip_pws_customer_check => 1,
    })->mech__multiple_reservation_select_reserve({
        variants                => \@variants,
        reservation_source_id   => 1,
    });

    like(
        $flow->mech->app_error_message,
        qr/No reservation type selected/i,
        "nothing to reserve"
    );

    $flow->errors_are_fatal(0);
    $flow->mech__multiple_reservation_select({
        customer_id             => $customer->id,
        skip_pws_customer_check => 1,
    })->mech__multiple_reservation_select_search({
        pids                    => join(',',@pids),
        skip_pws_customer_check => 1,
    })->mech__multiple_reservation_select_reserve({
        reservation_source_id   => 1,
        reservation_type_id   => 1,
    });

    like(
        $flow->mech->app_error_message,
        qr/No products selected/i,
        "nothing to reserve"
    );


    # Test: Complete working flow
    $flow->errors_are_fatal(1);
    $flow->mech__multiple_reservation_select({
        customer_id             => $customer->id,
        skip_pws_customer_check => 1,
    })->mech__multiple_reservation_select_search({
        pids                    => join(',',@pids),
        skip_pws_customer_check => 1,
    })->mech__multiple_reservation_select_reserve({
        reservation_source_id   => 1,
        reservation_type_id   => 1,
        variants                => \@variants,
    })->mech__multiple_reservation_confirm_reserve();

    my $reserved_items = $self->{schema}->resultset('Public::Reservation')->search({customer_id => $customer->id}, {})->count;

    cmp_ok(
        $reserved_items,
        '==',
        $expected_number_of_products,
        'Correct number of items reserved when confirmed'
    );

    foreach my $variant_id (@variants) {
        my $count = $self->{schema}->resultset('Public::Reservation')->search({
                customer_id => $customer->id,
                variant_id  => $variant_id,
                channel_id  => $channel->id,
            },{})->count;

        cmp_ok(
            $count,
            '==',
            1,
            'Found reservation for '.$variant_id,
        )
    }

}

Test::Class->runtests;

1;
