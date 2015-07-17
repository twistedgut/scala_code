#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 Public::Designer

A place to test methods & resultset methods for the 'Public::Designer' Class.

=cut

use DateTime;
use Test::XTracker::Data;
use XTracker::Constants::FromDB         qw( :designer_website_state );


# get a schema to query
my $schema  = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

#----------------------------------------------------
_check_required_params( $schema, 1 );
_test_designer_list_for_upload_date( $schema, 1 );
_test_designer_list_for_channel( $schema, 1 );
#----------------------------------------------------

done_testing;


# tests the 'list_for_upload_date' resultset method
sub _test_designer_list_for_upload_date {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_designer_list_for_upload_date", 1       if ( !$oktodo );

        note "TESTING: 'list_for_upload_date' Resultset Method";

        my $designer_rs = $schema->resultset('Public::Designer');

        $schema->txn_do( sub {
            my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
                                                    how_many    => 7,
                                                    channel     => Test::XTracker::Data->channel_for_nap,
                                            } );

            # create a few Designers
            my @designers;
            foreach my $designer_name ( (   # create them NOT in Alphabetical Order
                                            'My First Designer',
                                            'Designers R Us',
                                            'Couldn\'t think of a name',
                                        ) ) {
                my $url_key = lc( $designer_name );
                $url_key    =~ s/[^a-z,0-9,\s]//g;
                $url_key    =~ s/\s/_/g;
                push @designers, $designer_rs->update_or_create( {
                                                    designer    => $designer_name,
                                                    url_key     => $url_key,
                                                } );
            }

            # create some Upload Dates
            my $date_to_use = DateTime->now();
            $date_to_use->add( years => 1 );        # chose far into the future
            my @upload_dates;
            foreach ( 1..3 ) {
                $date_to_use->add( days => 1 );
                push @upload_dates, $date_to_use->clone;
            }
            $date_to_use->add( days => 1 );     # get a date that's NOT used

            # now assign the above Designers & Dates to the new PIDs
            # like so:
            #     pid1  - designer1 - date1
            #     pid2  - designer2 - date2
            #     pid3  - designer3 - date3
            #     pid4  - designer1 - date2
            #     pid5  - designer2 - date1
            #     pid6  - designer3 - date2
            #     pid7  - designer3 - date3     - This tests that the method is returning a Distinct Data Set
            #                                   - as Date 3 is against PIDs 3 & 7 which both have Designer 3

            my $idx = 0;
            foreach my $designer ( @designers[0..2,0..2,2] ) {
                $pids->[ $idx ]{product}->update( { designer_id => $designer->id } );
                $idx++;
            }
            $idx    = 0;
            foreach my $date ( @upload_dates[0..2,1,0,1,2] ) {
                my $date_to_use = $date->clone;
                $date_to_use->set( hour => 0, minute => 0, second => 0, nanosecond => 0 );
                $pids->[ $idx ]{product_channel}->update( { upload_date => $date_to_use } );
                $idx++;
            }

            my @tests   = (
                    {
                        label               => 'Expecting One Designer & ONLY One Record',
                        date_to_use         => $upload_dates[2],
                        expected_designers  => [ $designers[2] ],
                    },
                    {
                        label               => 'Expecting Two Designers',
                        date_to_use         => $upload_dates[0],
                        expected_designers  => [ @designers[1,0] ],     # expect them in Designer Name order
                    },
                    {
                        label               => 'Expecting Three Designers',
                        date_to_use         => $upload_dates[1],
                        expected_designers  => [ @designers[2,1,0] ],   # expect them in Designer Name order
                    },
                    {
                        label               => 'Expecting NO Designers',
                        date_to_use         => $date_to_use,
                        expected_designers  => [ ],
                    },
                );

            foreach my $test ( @tests ) {
                note "Test: " . $test->{label} . " with Date: " . $test->{date_to_use}->ymd('-');

                my @expected    = map { { $_->id => $_->designer } } @{ $test->{expected_designers} };

                my $rs      = $designer_rs->list_for_upload_date( $channel, $test->{date_to_use} );
                isa_ok( $rs, 'XTracker::Schema::ResultSet::Public::Designer', "Method returned as Expected" );

                my @recs    = $rs->all;
                cmp_ok( @recs, '==', @{ $test->{expected_designers} }, "returned Expected Number of Records" );
                my @got     = map { { $_->id => $_->designer } } @recs;
                is_deeply( \@got, \@expected, "and returned Expected Designer Records in Designer Name Order" );
            }


            # rollback changes
            $schema->txn_rollback();
        } );
    };

    return;
}

# check 'list_for_channel' ResultSet method
sub _test_designer_list_for_channel {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_designer_list_for_channel", 1           if ( !$oktodo );

        note "TESTING: 'list_for_channel' Resultset Method";

        my $designer_rs = $schema->resultset('Public::Designer');

        $schema->txn_do( sub {
            my @channels    = $schema->resultset('Public::Channel')->all;

            # create a few Designers
            my @designers;
            foreach my $designer_name ( (   # create them NOT in Alphabetical Order
                                            'My First Designer',
                                            'Designers R Us',
                                            'Name of Designer goes here',
                                            'ACDE',
                                            'Couldn\'t think of a name',
                                        ) ) {
                my $url_key = lc( $designer_name );
                $url_key    =~ s/[^a-z,0-9,\s]//g;
                $url_key    =~ s/s/_/g;
                push @designers, $designer_rs->create( {
                                                    designer    => $designer_name,
                                                    url_key     => $url_key,
                                                } );
            }

            # assign 3 Designers to each Sales Channel
            # but rotate which Designers so some are on
            # more than one Channel
            my %channels_to_designers;
            foreach my $channel ( @channels ) {
                $channel->designer_channels->delete;        # get rid of any existing Designer Channels

                foreach ( 1..3 ) {
                    my $designer    = shift @designers;
                    $designer->create_related( 'designer_channel', {
                                                        website_state_id=> $DESIGNER_WEBSITE_STATE__VISIBLE,
                                                        channel_id      => $channel->id,
                                                    } );
                    push @designers, $designer;
                    push @{ $channels_to_designers{ $channel->id } }, $designer;
                }
            }

            # now go through each Channel and call the method
            # to check the correct results are returned
            foreach my $channel ( @channels ) {
                note "Testing for Channel: " . $channel->name;

                # get the Expected designers in Alpha. Order
                my @expected    = map { $_->id }
                                    sort { $a->designer cmp $b->designer }
                                        @{ $channels_to_designers{ $channel->id } };

                my @got = $designer_rs->list_for_channel( $channel )->all;
                is_deeply( [ map { $_->id } @got ], \@expected,
                                        "Got Expected List in Alphabetical Order when using Channel Object" );

                @got    = $designer_rs->list_for_channel( $channel->id )->all;
                is_deeply( [ map { $_->id } @got ], \@expected,
                                        "Got Expected List in Alphabetical Order when using Channel Id" );

                cmp_ok( $got[0]->get_column('website_state_id'), '==', $DESIGNER_WEBSITE_STATE__VISIBLE,
                                        "Got Web Site State from the Record and is as Expected: Visible" );
            }


            # rollback changes
            $schema->txn_rollback;
        } );
    };

    return;
}


# check required parameters
sub _check_required_params {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_check_required_params", 1        if ( !$oktodo );

        note "TESTING: 'check_required_params'";

        my $designer_rs = $schema->resultset('Public::Designer');
        my $channel     = Test::XTracker::Data->channel_for_nap;
        my $now         = DateTime->now();

        note "Testing: 'list_for_upload_date' resultset method";
        my %tests   = (
                'Passing NO Params at all' => {
                        expected_error  => qr/No Channel Object has been passed/i,
                    },
                'Passing NO Channel' => {
                        params          => [ undef, $now ],
                        expected_error  => qr/No Channel Object has been passed/i,
                    },
                'Passing NO Date' => {
                        params          => [ $channel, undef ],
                        expected_error  => qr/No DateTime Object has been passed/i,
                    },
                'Passing a Channel but NOT a Channel Object' => {
                        params          => [ 'NAP', $now ],
                        expected_error  => qr/No Channel Object has been passed/i,
                    },
                'Passing a Date but NOT a DateTime Object' => {
                        params          => [ $channel, '2012-02-01' ],
                        expected_error  => qr/No DateTime Object has been passed/i,
                    },
                'Passing a Date & Channel the Wrong Way Round' => {
                        params          => [ $now, $channel ],
                        expected_error  => qr/No Channel Object has been passed/i,
                    },
            );

        foreach my $label ( keys %tests ) {
            my $test    = $tests{ $label };

            my @params  = ( $test->{params} ? @{ $test->{params} } : () );
            throws_ok {
                        (
                            @params
                            ? $designer_rs->list_for_upload_date( @params )
                            : $designer_rs->list_for_upload_date
                        );
                    }
                    $test->{expected_error},
                    $label . ": got Expected Error Message";
        }


        note "Testing: 'list_for_channel' resultset method";
        throws_ok {
                    $designer_rs->list_for_channel();
                }
                qr/No Channel Object or Channel Id/i,
                "Got 'No Channel' error when passed No Params";
        throws_ok {
                    $designer_rs->list_for_channel( { a => 1} );
                }
                qr/No Channel Object or Channel Id/i,
                "Got 'No Channel' error when passed something other than an Object or Id";
        throws_ok {
                    $designer_rs->list_for_channel( '23d' );
                }
                qr/No Channel Object or Channel Id/i,
                "Got 'No Channel' error when passed a string which isn't an Integer";
        throws_ok {
                    $designer_rs->list_for_channel( $now );
                }
                qr/No Channel Object or Channel Id/i,
                "Got 'No Channel' error when passed an object that isn't a Channel object";

    };

    return;
}
