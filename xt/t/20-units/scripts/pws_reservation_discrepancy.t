#!/usr/bin/env perl
use NAP::policy "tt",     'test';

=head2 Tests PWS Reservation Consistency

This will test elements used by the following script:
script/housekeeping/web_xt_consistency/pws_reservations_adjustment

Currently:
    * Public::Channel->generate_reservation_discrepancy_rows_to_insert
    * Public::Channel->reservations_by_sku

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::RunCondition export => [ qw( $distribution_centre ) ];

use XTracker::Constants::FromDB     qw(
                                        :reservation_status
                                    );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

#----------------------------------------------------------
_test_getting_skus_to_use( $schema, 1 );
#----------------------------------------------------------

done_testing();

# tests methods used to get SKU's used to check for
# Consistencies between the Web (PWS) and xTracker
sub _test_getting_skus_to_use {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_getting_skus_to_use", 1         if ( !$oktodo );

        note "in '_test_getting_skus_to_use'";

        $schema->txn_do( sub {
            # get any 'Uploaded' Reservations out of the way
            $schema->resultset('Public::Reservation')
                    ->search( { status_id => $RESERVATION_STATUS__UPLOADED } )
                        ->update( { status_id => $RESERVATION_STATUS__CANCELLED } );

            my $channel         = Test::XTracker::Data->channel_for_nap();
            my $stock_manager   = $channel->stock_manager;
            my $web_dbh         = $stock_manager->_web_dbh;

            my $pre_order_reservations  = Test::XTracker::Data::PreOrder->create_pre_order_reservations( {
                                                                                    channel         => $channel,
                                                                                    product_quantity=> 5,
                                                                                } );
            my $normal_reservations     = _create_reservations( 5, $channel );


            note "check 'reservations_by_sku' method when there are NO Uploaded Reservations";
            my $reservations_by_sku = $channel->reservations_by_sku();
            isa_ok( $reservations_by_sku, 'HASH', "method returned as Expected" );
            cmp_ok( keys %{ $reservations_by_sku }, '==', 0, "and is empty" );


            note "check 'reservations_by_sku' method with Uploaded Reservations";
            my @uploaded_preorder;
            my @uploaded_normal;
            my %expected;
            foreach my $idx ( 1..3 ) {
                # upload a few of the Reservations, the middle 3 of both Pre-Order and Normal
                push @uploaded_preorder, _upload_reservation( $pre_order_reservations->[ $idx ], \%expected, { pre_order_flag => 1 } );
                push @uploaded_normal, _upload_reservation( $normal_reservations->[ $idx ], \%expected, { pre_order_flag => 0 } );
            }
            my $got = $channel->reservations_by_sku;
            is_deeply( $got, \%expected, "method returned as Expected" );


            note "check 'generate_reservation_discrepancy_rows_to_insert' method when there are NO discrepencies";
            # mock up resultset for the Web DBH to return
            $web_dbh->{mock_add_resultset}  = [ [ 'customer_id', 'sku', 'quantity' ] ];     # just give the column headings
                                                                                            # but with no data

            my ( $discrepencies, $errors )  = $channel->generate_reservation_discrepancy_rows_to_insert( $stock_manager );
            isa_ok( $discrepencies, 'ARRAY', "method returned 'discrepencies array' as Expected" );
            cmp_ok( @{ $discrepencies }, '==', 0, "and is empty" );
            isa_ok( $errors, 'ARRAY', "method returned 'errors array' as Expected" );
            cmp_ok( @{ $errors }, '==', 0, "and is empty" );


            note "check 'generate_reservation_discrepancy_rows_to_insert' method when there are SOME discrepencies";

            # mock up resultset for the Web DBH to return
            my @mock_data;
            push @mock_data, _mock_up_web_data( 1, @uploaded_preorder[0,1], @uploaded_normal[1,2] );    # will have discrepencies
            push @mock_data, _mock_up_web_data( 0, $uploaded_preorder[2], $uploaded_normal[0] );        # no discrepency
            push @mock_data, [
                                $normal_reservations->[0]->customer->is_customer_number,
                                '9999999-99999',            # made up SKU that should throw an error
                                5,
                            ];
            $web_dbh->{mock_add_resultset}  = [ [ 'customer_id', 'sku', 'quantity' ], @mock_data ];

            my %expected_discrepencies;
            foreach my $reservation ( @uploaded_normal[1,2] ) {
                # should only see discrepencies for Normal Reservations
                my $key = $reservation->customer->is_customer_number . '_' . $reservation->variant_id;
                $expected_discrepencies{ $key } = {
                        customer_number => $reservation->customer->is_customer_number,
                        reported        => 1,
                        variant_id      => $reservation->variant_id,
                        web_quantity    => 10,
                        xt_quantity     => 1,
                    };
            }
            my @expected_errors = (
                        {
                            customer_number => $normal_reservations->[0]->customer->is_customer_number,
                            error           => "Could not find sku in XTracker's database\n",
                            pws_quantity    => 5,
                            sku             => '9999999-99999',
                            xt_quantity     => 'Unknown',
                        },
                    );

            ( $discrepencies, $errors ) = $channel->generate_reservation_discrepancy_rows_to_insert( $stock_manager );
            cmp_ok( @{ $discrepencies }, '==', 2, "method returned Expected number of elements in 'discrepencies array': 2" );
            isa_ok( $discrepencies->[0], 'HASH', "first 'discrepencies array' element is as Expected" );
            my %got_discrepencies   = map { $_->{customer_number} . '_' . $_->{variant_id} => $_ } @{ $discrepencies };
            is_deeply( \%got_discrepencies, \%expected_discrepencies, "and got All of the Discrepencies Expected" );
            is_deeply( $errors, \@expected_errors, "method returned 'errors array' as Expected" );


            # rollback any changes
            $schema->txn_rollback();
        } );
    };

    return;
}

#-------------------------------------------------------------------------------------

sub _create_reservations {
    my ( $number, $channel )    = @_;

    my @reservations;

    foreach my $counter ( 1..$number ) {
        my $data = Test::XT::Data->new_with_traits(
                        traits => [
                            'Test::XT::Data::ReservationSimple',
                        ],
                    );

        $data->channel( $channel );

        my $reservation = $data->reservation;
        $reservation->update( { ordering_id => $counter } );    # prioritise each reservation

        # make sure the Customer has a different Email
        # Address than every other Reservation's Customer
        $reservation->customer->update( { email => $reservation->customer->is_customer_number . '.test@net-a-porter.com' } );
        note "Customer Id/Nr: ".$reservation->customer->id."/".$reservation->customer->is_customer_number;
        note " -- Reservation Id: ".$reservation->id;

        push @reservations, $reservation;
    }

    return \@reservations;
}

# helper to Upload a Reservation
sub _upload_reservation {
    my ( $reservation, $expected, $args )   = @_;

    $reservation->update( { status_id => $RESERVATION_STATUS__UPLOADED } );
    $expected->{ $reservation->variant->sku } = {
                                        $reservation->customer->is_customer_number  => {
                                                variant_id      => $reservation->variant_id,
                                                quantity        => 1,
                                                is_for_preorder => $args->{pre_order_flag},
                                            },
                                        %{ $expected->{ $reservation->variant->sku } || {} },
                                    };

    return $reservation;
}

# helper to mock up data returned by the Web-Site
sub _mock_up_web_data {
    my ( $discrepency_flag, @reservations ) = @_;

    my @mock;

    foreach my $reservation ( @reservations ) {
        push @mock, [
                $reservation->customer->is_customer_number,
                $reservation->variant->sku,
                ( $discrepency_flag ? 10 : 1 ),     # if there should be a discrepency then
                                                    # set the Web Quantity to 10 which should
                                                    # be different to xTracker's which should
                                                    # always be 1 in the context of the tests
            ];
    }

    return @mock;
}
