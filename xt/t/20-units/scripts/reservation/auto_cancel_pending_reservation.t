#!/usr/bin/env perl
#
use NAP::policy "tt",         'test';

=head2 Auto Cancelling Pending Reservations


For CANDO-87

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XT::Data;

use DateTime;

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :reservation_status
                                        :season
                                    );

use XTracker::Script::Reservation::AutoCancelPending;


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );


#----------------------------------------------------------
_test_build_rs( $schema, 1 );
_test_cancellation( $schema, 1 );
_test_wrapper_script( $schema, 1 );
#----------------------------------------------------------

done_testing();


# this test checks the query in the Script which
# returns the ResultSet that the rest of the Script
sub _test_build_rs {
     my ( $schema, $oktodo )    = @_;

     SKIP: {
        skip "_test_build_rs", 1        if ( !$oktodo );

        note "TESTING: '_test_build_rs'";

        my $date_to_use = DateTime->now(time_zone => config_var('DistributionCentre', 'timezone'));
        my $date_now    = $date_to_use->clone;

        $schema->txn_do( sub {

            # set the Reservation Config Groups for each Sales Channel
            my @channels        = $schema->resultset('Public::Channel')
                                            ->fulfilment_only(0)
                                                ->search( {}, { order_by => 'id' } )
                                                    ->all;

            # get a Season except Continuity and Unknown
            my $allowed_season      = _get_an_allowed_season( $schema );
            my $continuity_season   = $schema->resultset('Public::Season')->find( $SEASON__CONTINUITY );

            my $channel_data        = _setup_expire_config_for_channels( \@channels, $date_to_use );


            note "Testing 'reservations_for_cancellation' for different Date Boundaries";

            # chek the ResultSet the script uses to Cancel Reservations
            my $to_cancel_rs    = XTracker::Script::Reservation::AutoCancelPending->new()->reservations_for_cancellation;
            isa_ok( $to_cancel_rs, 'XTracker::Schema::ResultSet::Public::Reservation', "'reservations_for_cancellation' ResultSet is as Expected" );

            my %tests   = (
                    "All Channels, All Reservations within expiration boundary" => {
                            reservations    => {
                                    lt_boundary     => [ @channels ],
                                },
                        },
                    "All Channels, All Reservations outside the expiration boundary" => {
                            reservations    => {
                                    gt_boundary     => [ @channels ],
                                },
                        },
                    "All Channels, All Reservations on the expiration boundary, all should get picked up" => {
                            reservations    => {
                                    on_boundary     => [ @channels ],
                                },
                        },
                    "All Channels, Reservations on, within & outside the expiration boundary" => {
                            reservations    => {
                                    on_boundary     => [ @channels ],
                                    lt_boundary     => [ @channels ],
                                    gt_boundary     => [ @channels ],
                                },
                        },
                    "Some Channel Reservations within the boundary One outside it" => {
                            reservations    => {
                                    lt_boundary     => [ @channels[0,1] ],
                                    gt_boundary     => [ $channels[2] ],
                                },
                        },
                    "One Channel inside the boundary all others outside"   => {
                            reservations    => {
                                    lt_boundary     => [ $channels[1] ],
                                    gt_boundary     => [ @channels[0,2] ],
                                },
                        },
                    "Only One Channel has Reservations inside the boundary, no Reservations for other Channels"   => {
                            reservations    => {
                                    lt_boundary     => [ $channels[1] ],
                                },
                        },
                    "Only One Channel has Reservations outside the boundary, no Reservations for other Channels"   => {
                            reservations    => {
                                    gt_boundary     => [ $channels[1] ],
                                },
                        },
                    "Only One Channel has Reservations on the boundary, no Reservations for other Channels"   => {
                            reservations    => {
                                    on_boundary     => [ $channels[1] ],
                                },
                        },
                    "All Channels, Reservations outside the boundary but with Continuity Season, none should get picked up" => {
                            reservations    => {
                                    gt_boundary     => [ @channels ],
                                    gt_season       => $continuity_season,
                                },
                        },
                    "All Channels, Reservations outside the boundary with Continuity Season and on the boundary with Allowed Season" => {
                            reservations    => {
                                    gt_boundary     => [ @channels ],
                                    gt_season       => $continuity_season,
                                    on_boundary     => [ @channels ],
                                    on_season       => $allowed_season,
                                },
                        },
                );

            foreach my $label ( keys %tests ) {
                note "Testing: $label";
                my $test    = $tests{ $label };

                my @expected_reservations;
                my @reservations;

                # create the Reservations required
                foreach my $boundary_type ( grep { /_boundary/ } keys %{ $test->{reservations} } ) {

                    my $boundary_channels   = $test->{reservations}{ $boundary_type };
                    $boundary_type          =~ m/(?<prefix>..)_.*/;
                    my $season_to_use       = $test->{reservations}{ $+{prefix} . '_season' } // $allowed_season;

                    foreach my $channel ( @{ $boundary_channels } ) {
                        my $reservation = _create_reservation(
                                                    $channel,
                                                    $channel_data->{ $channel->id }{ $boundary_type },
                                                    $season_to_use,
                                                );
                        push @reservations, $reservation;

                        # expect this record if it's ON or GREATER than the
                        # expiry boundary and NOT for the Continuity Season
                        push @expected_reservations, $reservation
                                        if ( $boundary_type =~ /(on|gt)_boundary/ && $season_to_use->id != $SEASON__CONTINUITY );
                    }
                }

                my $script  = XTracker::Script::Reservation::AutoCancelPending->new();
                $script->schema( $schema );
                my $rs  = $script->reservations_for_cancellation;
                my @got = $rs->all;

                cmp_ok( @got, '==', @expected_reservations, "Got Expected Number of Reservations returned" );
                is_deeply(
                            [ sort { $a <=> $b } map { $_->id } @got ],
                            [ sort { $a <=> $b } map { $_->id } @expected_reservations ],
                            "$label: Got Expected Reservation Id's returned"
                        );

                # get rid of Reservations for the next test
                foreach my $reservation ( @reservations ) {
                    $reservation->discard_changes->delete;
                }
            }


            note "Testing 'reservations_for_cancellation' for different Statuses";

            my $statuses    = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::ReservationStatus', {
                                                                                        allow   => [
                                                                                                $RESERVATION_STATUS__PENDING,
                                                                                            ],
                                                                                } );

            # create a reservation to use in the tests
            my $reservation = _create_reservation( $channels[0], $channel_data->{ $channels[0]->id }{'gt_boundary'}, $allowed_season );

            note "Statuses that should NOT return a Reservation";
            foreach my $status ( @{ $statuses->{not_allowed} } ) {
                $reservation->update( { status_id => $status->id } );
                my $script  = XTracker::Script::Reservation::AutoCancelPending->new();
                $script->schema( $schema );
                my $got = $script->reservations_for_cancellation->first;
                ok( !defined $got, "With Status: '" . $status->status . "' Reservation NOT Returned" );
            }

            note "Statuses that SHOULD return a Reservation";
            foreach my $status ( @{ $statuses->{allowed} } ) {
                $reservation->update( { status_id => $status->id } );
                my $script  = XTracker::Script::Reservation::AutoCancelPending->new();
                $script->schema( $schema );
                my $got = $script->reservations_for_cancellation->first;
                isa_ok( $got, 'XTracker::Schema::Result::Public::Reservation', "With Status: '" . $status->status . "' Reservation Returned" );
            }
            # remove Reservation to get out of way of future tests
            $reservation->delete;


            note "Testing Pre-Order Pending Reservations are Excluded";
            my $pre_ord_reservation = Test::XTracker::Data::PreOrder->create_pre_order_reservations({
                                                        reservation_status      => $RESERVATION_STATUS__PENDING,
                                                        channel                 => $channels[0],
                                                        product_quantity        => 1,
                                                        variants_per_product    => 1,
                                                } )->[0];
            # update the Season so it would be picked up
            $pre_ord_reservation->variant
                                    ->product
                                        ->update( {
                                                season_id   => $allowed_season->id,
                                            } );

            {
                # inside a code block so that the instance of the Script is
                # destroyed to avoid the Singleton constraint that's on the Script
                $pre_ord_reservation->update( {
                                        date_created    => $channel_data->{ $channels[0]->id }{'lt_boundary'},
                                    } );
                my $script  = XTracker::Script::Reservation::AutoCancelPending->new();
                $script->schema( $schema );
                ok( !defined $script->reservations_for_cancellation->first,
                                        "Pending Pre-Order Reservation Less than the Boundary NOT Found" );

            };
            {
                # inside a code block so that the instance of the Script is
                # destroyed to avoid the Singleton constraint that's on the Script
                $pre_ord_reservation->update( {
                                        date_created    => $channel_data->{ $channels[0]->id }{'gt_boundary'},
                                    } );
                my $script  = XTracker::Script::Reservation::AutoCancelPending->new();
                $script->schema( $schema );
                ok( !defined $script->reservations_for_cancellation->first,
                                    "Pending Pre-Order Reservation Greater than the Boundary NOT Found" );
            };


            note "Testing 'reservations_for_cancellation' with NO Channelised System Config values, dies";
            foreach my $channel ( @channels ) {
                Test::XTracker::Data->remove_config_group( 'Reservation', $channel );
            }

            dies_ok {
                    my $script  = XTracker::Script::Reservation::AutoCancelPending->new();
                    $script->schema( $schema );
                    $script->reservations_for_cancellation;
                } "With no System Config Values 'reservations_for_cancellation' dies when called";


            # rollback changes
            $schema->txn_rollback();
        } );
    };

    return;
}

# this tests that Reservations get Cancelled when they
# should and don't get Cancelled when they shouldn't
sub _test_cancellation {
    my ( $schema, $oktodo ) = @_;

    SKIP: {
        skip "_test_cancellation", 1        if ( !$oktodo );

        note "TESTING: '_test_cancellation'";

        my $date_now    = DateTime->now(time_zone => config_var('DistributionCentre', 'timezone'));

        $schema->txn_do( sub {
            my @channels        = $schema->resultset('Public::Channel')
                                            ->fulfilment_only(0)
                                                ->search( {}, { order_by => 'id' } )
                                                    ->all;

            my $channel_data    = _setup_expire_config_for_channels( \@channels, $date_now );
            my $allowed_season  = _get_an_allowed_season( $schema );

            my @reservation_to_change;
            my @reservation_to_not_change;

            # generate Reservations to use in tests
            foreach my $channel ( @channels ) {
                my $date_to_use = $channel_data->{ $channel->id }{'gt_boundary'};
                my $reservation = _create_reservation( $channel, $date_to_use, $allowed_season );
                push @reservation_to_change, $reservation;

                $date_to_use    = $channel_data->{ $channel->id }{'on_boundary'};
                $reservation    = _create_reservation( $channel, $date_to_use, $allowed_season );
                push @reservation_to_change, $reservation;

                $date_to_use    = $channel_data->{ $channel->id }{'lt_boundary'};
                $reservation    = _create_reservation( $channel, $date_to_use, $allowed_season );
                push @reservation_to_not_change, $reservation;
            }

            note "Override the Script's Result Set to specifically use Reservations Created";
            my $rs_for_script   = $schema->resultset('Public::Reservation')
                                            ->search( {
                                                        id => { 'IN' => [
                                                            map { $_->id }
                                                                ( @reservation_to_change )
                                                        ] }
                                                    } );


            note "Test Running the Script in 'dryrun' mode, nothing should happen";
            _run_script( $schema, $rs_for_script, { dryrun => 1 } );
            _check_reservations_not_cancelled( $schema, $date_now, \@reservation_to_change );


            note "Test Running the Script in normal mode, something should happen";
            _run_script( $schema, $rs_for_script );
            _check_reservations_cancelled( $schema, $date_now, \@reservation_to_change );
            _reset_reservations( @reservation_to_change );


            note "Test with Some Reservations Statuses set to something other than Pending (Uploaded), they shouldn't get Cancelled";
            $_->update( { status_id => $RESERVATION_STATUS__UPLOADED } )
                                            foreach ( @reservation_to_change[0..2] );
            _run_script( $schema, $rs_for_script );
            _check_reservations_cancelled( $schema, $date_now, [ @reservation_to_change[ 3..$#reservation_to_change ] ] );
            _check_reservations_not_cancelled( $schema, $date_now, [ @reservation_to_change[0..2] ] );
            _reset_reservations( @reservation_to_change[ 3..$#reservation_to_change ] );


            note "Test running the Script without Overiding its Result Set to run Normally";
            _run_script( $schema );
            _check_reservations_cancelled( $schema, $date_now, [ @reservation_to_change[ 3..$#reservation_to_change ] ] );
            _check_reservations_not_cancelled( $schema, $date_now, [ @reservation_to_not_change, @reservation_to_change[0..2] ] );
            _reset_reservations( @reservation_to_change );


            note "Test running in Verbose & Dry-Run mode just to make sure Verbose doesn't interfere";
            _run_script( $schema, undef, { dryrun => 1, verbose => 1 } );
            _check_reservations_not_cancelled( $schema, $date_now, [ @reservation_to_change, @reservation_to_not_change ] );


            note "Test running normally but in Verbose mode just to make sure Verbose doesn't interfere";
            _run_script( $schema, undef, { verbose => 1 } );
            _check_reservations_cancelled( $schema, $date_now, \@reservation_to_change );
            _check_reservations_not_cancelled( $schema, $date_now, \@reservation_to_not_change );


            # rollback changes
            $schema->txn_rollback();
        } );
    };

    return;
}

# tests the Wrapper Script which is actually
# what gets executed, called in 'dryrun' mode
sub _test_wrapper_script {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_wrapper_script", 1          if ( !$oktodo );

        note "TESTING: '_test_wrapper_script'";

        my $channel         = Test::XTracker::Data->channel_for_nap;
        my $allowed_season  = _get_an_allowed_season( $schema );
        my $cancel_boundary = $schema->resultset('SystemConfig::ConfigGroupSetting')
                                        ->config_var( 'Reservation', 'expire_pending_after', $channel->id );
        my $reservation     = _create_reservation( $channel, undef, $allowed_season );
        $reservation->update( { date_created => \"now() - interval '$cancel_boundary'" } );

        # check the house keeping script exists
        my $script  = config_var( 'SystemPaths', 'script_dir' ) . '/housekeeping/reservations/auto_cancel_pending.pl';

        my $file_check  = 0;
        if ( -e $script ) {
            $file_check = 1 ;
        }

        # check existence of script
        is( $file_check, 1, "Script '${script}' Exists" );

        note "Execute Script in 'dryrun' mode";
        system( $script, '-d' );    # run script in Dry-Run mode
        my $retval  = $?;
        if ( $retval == -1 ) {
            fail( "Script failed to Execute: ${retval}" )
        }
        else {
            cmp_ok( ( $retval & 127 ), '==', 0, "Script Executed OK: ${retval}" );
        }

        cmp_ok( $reservation->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING,
                                    "Reservation Status Id is STILL 'Pending'" );
        $reservation->delete;
    };

    return;
}

#-------------------------------------------------------------------------------------

# check Reservations did get Cancelled
sub _check_reservations_cancelled {
    my ( $schema, $date_now, $reservations_to_chk )     = @_;

    note "Checking Reservations HAVE been Cancelled";

    foreach my $reservation ( @{ $reservations_to_chk } ) {
        note "Reservation Id: " . $reservation->discard_changes->id;

        cmp_ok( $reservation->status_id, '==', $RESERVATION_STATUS__CANCELLED,
                                "Reservation Status is Cancelled" );
        ok( defined $reservation->date_expired, "Reservation Expiry Date has been updated" );

        my $log = $reservation->reservation_auto_change_logs->first;
        isa_ok( $log, 'XTracker::Schema::Result::Public::ReservationAutoChangeLog',
                                "Found a 'reservation_auto_change_log' record" );
        cmp_ok( $log->pre_status_id, '==', $RESERVATION_STATUS__PENDING,
                                "Log 'pre_status_id' is Pending" );
        cmp_ok( $log->post_status_id, '==', $RESERVATION_STATUS__CANCELLED,
                                "Log 'post_status_id' is Cancelled" );
        cmp_ok( $log->operator_id, '==', $APPLICATION_OPERATOR_ID,
                                "Log 'operator_id' is for App User" );
    }

    return;
}

# check Reservations did NOT get Cancelled
sub _check_reservations_not_cancelled {
    my ( $schema, $date_now, $reservations_to_chk )     = @_;

    note "Checking Reservations Have NOT been Cancelled";

    foreach my $reservation ( @{ $reservations_to_chk } ) {
        note "Reservation Id: " . $reservation->discard_changes->id;

        cmp_ok( $reservation->status_id, '!=', $RESERVATION_STATUS__CANCELLED,
                                "Reservation Status is NOT Cancelled" );
        ok( !defined $reservation->date_expired, "Reservation Expiry Date is still 'undef'" );
        cmp_ok( $reservation->reservation_auto_change_logs->count, '==', 0,
                                "NO 'reservation_auto_change_log' records found" );
    }

    return;
}

# resets Reservations back to Pending
sub _reset_reservations {
    my @reservations    = @_;

    foreach my $reservation ( @reservations ) {
        $reservation->discard_changes->update( {
                                            status_id       => $RESERVATION_STATUS__PENDING,
                                            date_expired    => undef,
                                        } );
        $reservation->reservation_auto_change_logs->delete;
    }

    return;
}

sub _run_script {
    my ( $schema, $reservation_rs, $args )      = @_;

    my $runopts = {
            verbose     => 0,
            dryrun      => 0,
            ( $args ? %{ $args } : () )
        };

    my $script  = XTracker::Script::Reservation::AutoCancelPending->new( $runopts );
    $script->schema( $schema );
    $script->reservations_for_cancellation( $reservation_rs->reset )        if ( $reservation_rs );
    $script->invoke();

    return $script;
}

sub _create_reservation {
    my ( $channel, $date_created, $season ) = @_;

    my $data = Test::XT::Data->new_with_traits(
                    traits => [
                        'Test::XT::Data::ReservationSimple',
                    ],
                );
    $data->always_create_new_products( 1 );     # need new products everytime as need to change their Seasons
    $data->channel( $channel );

    my $reservation = $data->reservation;
    $reservation->update( { date_created => $date_created } )       if ( $date_created );
    $reservation->variant
                    ->product->update( { season_id => $season->id } );
    $reservation->reservation_auto_change_logs->delete;

    note "created Reservation for Season: '" . $season->season . "' with Date Created: '" . $reservation->date_created->datetime . "'";

    return $reservation->discard_changes;
}

# get an Allowed Season
sub _get_an_allowed_season {
    my ( $schema )      = @_;

    return $schema->resultset('Public::Season')
                                ->search(
                                        {
                                            id      => { 'NOT IN' => [ 0, $SEASON__CONTINUITY ] },
                                            active  => 1,
                                        },
                                        {
                                            order_by => 'season_year DESC'
                                        }
                                    )->first;
}

# sets up the Reservation Expire config
# for a given set of Sales Channels
sub _setup_expire_config_for_channels {
    my ( $channels, $date_to_use )      = @_;

    my %channel_data;
    my $months  = 3;

    foreach my $channel ( @{ $channels } ) {
        Test::XTracker::Data->remove_config_group( 'Reservation', $channel );
        Test::XTracker::Data->create_config_group( 'Reservation', {
                                                    channel => $channel,
                                                    settings=> [
                                                            { setting => 'expire_pending_after', value => "${months} months" },
                                                        ],
                                                } );

        # clear out any Pending Reservations
        $channel->reservations->search( { status_id => $RESERVATION_STATUS__PENDING } )
                                ->update( { status_id => $RESERVATION_STATUS__CANCELLED } );

        $channel_data{ $channel->id }   = {
                            months      => $months,
                            channel     => $channel,
                            # set-up three types of dates to use
                            on_boundary => $date_to_use->clone->subtract( months => $months, end_of_month => 'limit' ),
                            gt_boundary => $date_to_use->clone->subtract( months => ( $months + 1 ), end_of_month => 'limit' ),
                            lt_boundary => $date_to_use->clone->subtract( months => ( $months - 1 ), end_of_month => 'limit' ),
                        };

        $months++;
    }

    return \%channel_data;
}
