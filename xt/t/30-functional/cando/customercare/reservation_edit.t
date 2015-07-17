#!/usr/bin/env perl
use NAP::policy qw( test class );
BEGIN { extends "NAP::Test::Class" }

use Test::XT::Flow;
use Test::XTracker::Data::Operator;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :department
    :reservation_status
);


=head1 NAME

 Test Reservation Edit functionality

=head1 DESCRIPTION

Tests Editing of 'Live Reservation' page and 'Product Search' page under Stock Control -> Reservations

 * Tests Customer Care/Manager is not able to edit Personal Shopping/Fashion Advisor reservations.

=head1 TESTS

=head2 test_startup


=cut

sub test_startup : Test( startup => no_plan ) {
    my $self = shift;

    #create operator
    $self->{operator_1} = Test::XTracker::Data::Operator->create_new_operator;
    $self->{operator}   = Test::XTracker::Data->_get_operator( 'it.god' );
    $self->{schema}     = Test::XTracker::Data->get_schema();

}

=head2 test_setup

=cut

sub test_setup : Test( setup => no_plan ) {
    my $self = shift;

    $self->{flow} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Reservations',
            'Test::XT::Data::ReservationSimple',
        ],
    );
    my $product = $self->{flow}->product;

    # Delete all reservation for this product
    Test::XTracker::Data->delete_reservations( { product => $product } );

    # Set product to choose for reservation
    $self->{flow}->_set_product( $product );
}

=head2 test_reservation_edit

Tests editing of reservations on 'Live Reservation' page.

=cut

sub test_reservation_edit: Tests(){
    my $self = shift;

    my $flow = $self->{flow};
    my $reservation = $flow->reservation;
    isa_ok( $reservation, 'XTracker::Schema::Result::Public::Reservation', 'New reservation' );


    my %tests = (
        "Logged in as Customer Care" => {
            setup => {
                department => 'Customer Care'
            },
            expected => {
                '- Expiry Date +' => '',
                'Delete'          => '',
                form_submit       =>  0,
            },
        },
        "Logged in as Customer Care Manager" => {
            setup => {
                department => 'Customer Care Manager'
            },
            expected => {
                '- Expiry Date +' => '',
                'Delete'          => '',
                form_submit       =>  0,
            },
        },
        "Logged in as Personal Shopper" => {
            setup => {
                department => 'Personal Shopping'
            },
            expected => {
                '- Expiry Date +' => [
                    'input_name',
                    'input_value',
                    'value',
                ],
                'Delete' => [
                    'input_name',
                    'input_value',
                    'value',
                ],
                form_submit => 1,
          }
        },
        "Logged in as Fashion Advisor" => {
            setup => {
                department => 'Fashion Advisor'
            },
            expected => {
                '- Expiry Date +' => [
                    'input_name',
                    'input_value',
                    'value',
                ],
                'Delete' => [
                    'input_name',
                    'input_value',
                    'value',
                ],
                form_submit  => 1,
          }
    });

    # Reset reservation
    $self->{operator_1}->discard_changes()->update( { department_id => $DEPARTMENT__PERSONAL_SHOPPING } );
    $reservation->discard_changes->update( {
        operator_id   =>  $self->{operator_1}->id,
        status_id => $RESERVATION_STATUS__UPLOADED,
        date_expired => undef
    } );


    foreach my $label (sort keys %tests ) {
        note "Testing: ${label}";

        my $test = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expected};


        # Login as a specific department.
        $flow->login_with_permissions({
            perms => { $AUTHORISATION_LEVEL__OPERATOR => [
                'Stock Control/Reservation',
            ]},
            dept => $setup->{department},
        });

        $flow->mech__reservation__summary;
        $flow->mech__reservation__summary->mech__reservation__summary_click_live
            ->mech__reservation__apply_filter( 'all' );

        my $page_data = $flow->mech->as_data->{reservations_by_operator};

        my $got  = {};
        my $data = $page_data->{$reservation->channel->name}->{$self->{operator_1}->id}[0][0];
        my $form = delete ( $expect->{form_submit} );

        # Get Expiry Date data
        if ( ref $data->{'- Expiry Date +'} eq 'HASH' ){
            push @{ $got->{'- Expiry Date +'} }, sort keys %{ $data->{'- Expiry Date +'} };
        } else {
            $got->{'- Expiry Date +'} = $data->{'- Expiry Date +'};
        }

        if( ref $data->{'Delete'} eq 'HASH'  ) {
            push @{ $got->{'Delete'} }, sort keys %{ $data->{'- Expiry Date +'} };
        } else {
             $got->{'Delete'} = $data->{'Delete'};
        }

        cmp_deeply($got, $expect, "Delete and Expiry Date were as expected" );

        if( $form ) {
            $flow->mech__reservation__listing_reservations__edit(
                $reservation->customer->id, {
                    edit_expiry => [
                        { $reservation->id => '23-01-2100' },
                    ],
            });

            like( $flow->mech->app_status_message, qr/Reservation successfully updated/ );

        } else {
            $flow->errors_are_fatal(0);
            $flow->mech__reservation__listing_reservations__edit(
                    $reservation->customer->id,
                    {
                        edit_expiry => [
                            { $reservation->id => '23-01-2100' },
                        ],
                    }
            );
            $flow->mech->has_feedback_error_ok( qr/Unable to update reservation changes as reservation belongs to/ );
            $flow->errors_are_fatal(1);
        }

    }

}

=head2 test_reservation_product_page

Tests editing of reservations on 'Product Search' page.

=cut

sub test_reservation_product_page : Tests() {
    my $self = shift;

    my $flow = $self->{flow};
    my $reservation = $flow->reservation;
    isa_ok( $reservation, 'XTracker::Schema::Result::Public::Reservation', 'New reservation' );

    my %tests = (
        "Logged in as Customer Care" => {
            setup => {
                department => 'Customer Care'
            },
            expected => {
                'action'      => '',
                'form_submit' => 0,
            },
        },
        "Logged in as Customer Care Manager" => {
            setup => {
                department => 'Customer Care Manager'
            },
            expected => {
                'action' => '',
                'form_submit' => 0,
            },
        },
        "Logged in as Personal Shopper" => {
            setup => {
                department => 'Personal Shopping'
            },
            expected => {
                'action' => [
                    'url',
                    'value',
                ],
                'form_submit' => 1,
          }
        },
        "Logged in as Fashion Advisor" => {
            setup => {
                department => 'Fashion Advisor'
            },
            expected => {
                'action' => [
                    'url',
                    'value',
                ],
            'form_submit' => 1,
          }
    });

    # Reset the data
    $self->{operator_1}->discard_changes()->update( { department_id => $DEPARTMENT__PERSONAL_SHOPPING } );
    $reservation->discard_changes()->update( {
        operator_id =>  $self->{operator_1}->id,
        status_id => $RESERVATION_STATUS__UPLOADED
    } );

    foreach my $label (sort keys %tests ) {
        note "Testing: ${label}";

        my $test = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expected};


        # Login as a specific department.
        $flow->login_with_permissions({
            perms => { $AUTHORISATION_LEVEL__OPERATOR => [
                'Stock Control/Reservation',
            ]},
            dept => $setup->{department},
        });

        # Go to Product Page which should have the above Reservations on it
        $flow->mech__reservation__summary
            ->mech__reservation__product_search
            ->mech__reservation__product_search_submit(
                 { product_id => $reservation->variant->product_id, }
            );

        my $mech      = $flow->mech;
        my $form      = delete ( $expect->{form_submit} );

        my $page_data = $flow->mech->as_data->{reservation_list}->{$reservation->channel->name}->{reservation}->{$reservation->variant_id};
        my $got = {};

        note "Logged in operator name and department ".
             $mech->logged_in_as_object->username . " - ".
             $mech->logged_in_as_object->department->department;
        note "Reservation operator name an department ".
             $reservation->discard_changes->operator->username. " - ".
             $reservation->discard_changes->operator->department->department;

        #make sure reservation is for Personal shopper
        cmp_ok( $reservation->operator->department_id,
                '==',
                $DEPARTMENT__PERSONAL_SHOPPING,
                'Reservation is for Personal Shopper'
        );


        if ( ref $page_data->{customers}[0]->{''} eq 'HASH' ){
             push @{ $got->{'action'} }, sort keys %{ $page_data->{customers}[0]->{''} };
        } else {
            $got->{action} = $page_data->{customers}[0]->{''};
        }

        cmp_deeply($got, $expect, "Results are as expected" )
            or diag "ERROR - Results are as expected :\n".
                    "GOT  - ".p($got)."\n".
                    "EXPECTED - ".p($expect)."\n".
                    "Page Content - ". $mech->content;

        if( !$form ) {
            dies_ok { $flow->mech__reservation__cancel_reservation( $reservation->id ) } 'Dies ok';
        }

    }

}
Test::Class->runtests;

