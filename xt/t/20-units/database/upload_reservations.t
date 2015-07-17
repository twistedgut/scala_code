#!/usr/bin/env perl

use NAP::policy "tt",         'test';
use DateTime;

use Test::XTracker::Data;
use Test::XTracker::RunCondition export => [ '$distribution_centre' ];
use Test::XTracker::ParamCheck;

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants             qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB     qw( :currency :country :sub_region );
use XTracker::Database::Invoice     qw( get_invoice_country_info );

use DateTime;
use Math::Round;


BEGIN {
    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Database::Reservation', qw(
                            get_upload_reservations
                        ) );

    can_ok("XTracker::Database::Reservation", qw(
                            get_upload_reservations
                        ) );
}

my $schema  = Test::XTracker::Data->get_schema();
my $dbh     = $schema->storage->dbh;

#---- Test Functions ------------------------------------------

_test_funcs($dbh,$schema,1);
_test_filtering_upload_reservations( $schema, 1 );

#--------------------------------------------------------------

done_testing();

#---- TEST FUNCTIONS ------------------------------------------

# This tests functions
sub _test_funcs {

    my $dbh     = shift;
    my $schema  = shift;

    my $tmp;
    my @tmp;

    SKIP: {
        skip "_test_funcs", 1           if (!shift);

        note "TESTING get_upload_reservations function";

        $schema->txn_do( sub {
            # get products
            my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
                                                                channel => 'nap',
                                                                how_many => 1,
                                                        } );
            # get the relevant products out of the ARRAY
            isa_ok( my $prod_chan = $pids->[0]{product_channel}, 'XTracker::Schema::Result::Public::ProductChannel' );
            isa_ok( my $product = $pids->[0]{product}, 'XTracker::Schema::Result::Public::Product' );
            note "Using PID: ".$product->id;
            note "On DC    : ".$distribution_centre;

            my $country = $schema->resultset('Public::Country')->search( { country => config_var('DistributionCentre','country') } )->first;

            # set an upload date
            $prod_chan->update( { upload_date => DateTime->now( time_zone => "local" ) } );
            $product->search_related('price_country')->delete;
            $product->search_related('price_region')->delete;
            $product->search_related('price_default')->delete;

            if ( $distribution_centre eq "DC1" ) {
                # change the tax rate to minimise co-incidence of hard coded
                # vat rate being correct, set it to something high
                $country->country_tax_rate->update( { rate => 0.415 } );

                my $uk_tax      = get_invoice_country_info( $dbh, 'United Kingdom' );
                my $vat         = $uk_tax->{rate};

                # work out the test price + vat, and round to 2 decimal places
                my $test_price  = sprintf( "%0.2f", 123.45 * ( 1 + $vat ) );

                note "Call function expecting 'price_default' back: ".$test_price;
                $product->create_related( 'price_default', {
                                            price       => 123.45,
                                            currency_id => $country->currency_id,
                                            operator_id => $APPLICATION_OPERATOR_ID,
                                        } );
                $tmp    = get_upload_reservations( $dbh, $channel->id, $prod_chan->upload_date->dmy('-') );
                # find our product and check price
                foreach my $prod ( values %{ $tmp } ) {
                    if ( $prod->{id} == $product->id ) {
                        # get price out of price field which now has
                        # a currency sympbol prefix followed by a space
                        if ($prod->{price}  =~ m/.* (.*)/) {
                            cmp_ok( $1, '==', $test_price, "Price Default found" );
                        }
                        else {
                            fail("Price Default format wrong");
                        }
                    }
                }

                note "Call function expecting 'price_country' back: 543.21";
                $product->create_related( 'price_country', {
                                            price       => 543.21,
                                            country_id  => $country->id,
                                            currency_id => $country->currency_id,
                                            operator_id => $APPLICATION_OPERATOR_ID,
                                        } );
                $tmp    = get_upload_reservations( $dbh, $channel->id, $prod_chan->upload_date->dmy('-') );
                # find our product and check price
                foreach my $prod ( values %{ $tmp } ) {
                    if ( $prod->{id} == $product->id ) {
                        # get price out of price field which now has
                        # a currency sympbol prefix followed by a space
                        if ($prod->{price}  =~ m/.* (.*)/) {
                            cmp_ok( $1, '==', 543.21, "Price Country found" );
                        }
                        else {
                            fail("Price Country format wrong");
                        }
                    }
                }
            }
            elsif ( $distribution_centre eq 'DC2' ) {
                note "Call function expecting 'price_default' back: 123.45";
                $product->create_related( 'price_default', {
                                            price       => 123.45,
                                            currency_id => $country->currency_id,
                                            operator_id => $APPLICATION_OPERATOR_ID,
                                        } );
                $tmp    = get_upload_reservations( $dbh, $channel->id, $prod_chan->upload_date->dmy('-') );
                # find our product and check price
                foreach my $prod ( values %{ $tmp } ) {
                    if ( $prod->{id} == $product->id ) {
                        # get price out of price field which now has
                        # a currency sympbol prefix followed by a space
                        if ($prod->{price}  =~ m/.* (.*)/) {
                            cmp_ok( $1, '==', 123.45, "Price Default found" );
                        }
                        else {
                            fail("Price Default format wrong");
                        }
                    }
                }

                note "Call function expecting 'price_region' back: 543.21";
                $product->create_related( 'price_region', {
                                            price       => 543.21,
                                            region_id   => $country->sub_region->region_id,
                                            currency_id => $country->currency_id,
                                            operator_id => $APPLICATION_OPERATOR_ID,
                                        } );
                $tmp    = get_upload_reservations( $dbh, $channel->id, $prod_chan->upload_date->dmy('-') );
                # find our product and check price
                foreach my $prod ( values %{ $tmp } ) {
                    if ( $prod->{id} == $product->id ) {
                        # get price out of price field which now has
                        # a currency symbol prefix followed by a space
                        if ($prod->{price}  =~ m/.* (.*)/) {
                            cmp_ok( $1, '==', 543.21, "Price Region found" );
                        }
                        else {
                            fail("Price Region format wrong");
                        }

                    }
                }
            }
            elsif ( $distribution_centre eq 'DC3' ) {

                note "Call function expecting 'price_default' back: 123.45";
                $product->create_related( 'price_default', {
                                            price       => 123.45,
                                            currency_id => $country->currency_id,
                                            operator_id => $APPLICATION_OPERATOR_ID,
                                        } );
                $tmp    = get_upload_reservations( $dbh, $channel->id, $prod_chan->upload_date->dmy('-') );
                # find our product and check price
                foreach my $prod ( values %{ $tmp } ) {
                    if ( $prod->{id} == $product->id ) {
                        # get price out of price field which now has
                        # a currency sympbol prefix followed by a space
                        if ($prod->{price}  =~ m/.* (.*)/) {
                            cmp_ok( $1, '==', 123.45, "Price Default found" );
                        }
                        else {
                            fail("Price Default format wrong");
                        }
                    }
                }

                note "Call function expecting 'price_country' back: 543.21";
                $product->create_related( 'price_country', {
                                            price       => 543.21,
                                            country_id  => $country->id,
                                            currency_id => $country->currency_id,
                                            operator_id => $APPLICATION_OPERATOR_ID,
                                        } );
                $tmp    = get_upload_reservations( $dbh, $channel->id, $prod_chan->upload_date->dmy('-') );
                # find our product and check price
                foreach my $prod ( values %{ $tmp } ) {
                    if ( $prod->{id} == $product->id ) {
                        # get price out of price field which now has
                        # a currency sympbol prefix followed by a space
                        if ($prod->{price}  =~ m/.* (.*)/) {
                            cmp_ok( $1, '==', 543.21, "Price Country found" );
                        }
                        else {
                            fail("Price Country format wrong");
                        }
                    }
                }

            } else {
                BAIL_OUT("Test is not configured for: $distribution_centre");
            }

            # undo any changes
            $schema->txn_rollback();
        } );

    }
}

# tests filtering by Designer or Products the list
# returned by 'get_upload_reservations' function
sub _test_filtering_upload_reservations {
    my ( $schema, $oktodo )     = @_;

    my $dbh     = $schema->storage->dbh;

    SKIP: {
        skip "_test_filtering_upload_reservations", 1           if (!$oktodo);

        note "TESTING Filtering using the get_upload_reservations function";

        $schema->txn_do( sub {
            # get products
            my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
                                                                channel => 'nap',
                                                                how_many => 5,
                                                        } );

            my @designers;
            my $designer_rs     = $schema->resultset('Public::Designer');
            foreach my $designer_name ( (
                                    'New Designer',
                                    'Another Designer',
                                ) ) {

                my $url_key = lc( $designer_name );
                $url_key    =~ s/[^a-z,0-9,\s]//g;
                $url_key    =~ s/\s/_/g;
                push @designers, $designer_rs->update_or_create( {
                            designer    => $designer_name,
                            url_key     => $url_key,
                        } );
            }

            # assigner the Designers to some PIDs
            $pids->[0]{product}->update( { designer_id => $designers[0]->id } );
            $pids->[2]{product}->update( { designer_id => $designers[1]->id } );

            # set an Upload Date far in the future for all the PIDs
            my $upload_date = DateTime->now()->add( years => 1 );
            foreach my $pid ( @{ $pids } ) {
                $pid->{product_channel}->update( { upload_date => $upload_date } );
            }

            my %tests   = (
                    'No Filtering Get ALL PIDs'  => {
                            expected    => [ map { $_->{product} } @{ $pids } ],
                        },
                    'Using undef Filtering Option, Get ALL PIDs'  => {
                            exclude     => undef,
                            expected    => [ map { $_->{product} } @{ $pids } ],
                        },
                    'Using Unknown Filtering Option, Get ALL PIDs'  => {
                            exclude     => { unknown => [1,2] },
                            expected    => [ map { $_->{product} } @{ $pids } ],
                        },
                    'Exclude Designers' => {
                            exclude => {
                                    exclude_designer_ids    => [ map { $_->id } @designers ],
                                },
                            expected    => [ map { $_->{product} } @{ $pids }[1,3,4] ],
                        },
                    'Exclude Products' => {
                            exclude => {
                                    exclude_pids    => [ map { $_->{product}->id } @{ $pids }[0,4] ],
                                },
                            expected    => [ map { $_->{product} } @{ $pids }[1..3] ],
                        },
                    'Exclude Designers & Products' => {
                            exclude => {
                                    exclude_designer_ids=> [ map { $_->id } $designers[1] ],
                                    exclude_pids        => [ map { $_->{product}->id } $pids->[4] ],
                                },
                            expected    => [ map { $_->{product} } @{ $pids }[0,1,3] ],
                        },
                    'Exclude Multiple Designers & Products' => {
                            exclude => {
                                    exclude_designer_ids=> [ map { $_->id } @designers ],
                                    exclude_pids        => [ map { $_->{product}->id } @{ $pids }[1,3] ],
                                },
                            expected    => [ map { $_->{product} } $pids->[4] ],
                        },
                    'Exclude All Products' => {
                            exclude => {
                                    exclude_pids    => [ map { $_->{product}->id } @{ $pids } ],
                                },
                            expected    => [],
                        },
                );

            foreach my $label ( keys %tests ) {
                note "Test: $label";
                my $test    = $tests{ $label };

                my $got = (
                            exists( $test->{exclude} )
                            ? get_upload_reservations( $dbh, $channel->id, $upload_date->dmy('-'), { filter => $test->{exclude} } )
                            : get_upload_reservations( $dbh, $channel->id, $upload_date->dmy('-') )
                          );
                is_deeply(
                        [ sort { $a <=> $b } map { $_->{id} } values %{ $got } ],
                        [ sort { $a <=> $b } map { $_->id } @{ $test->{expected} } ],
                        "Got the Expected Products Returned"
                    );
            }


            # rollback changes
            $schema->txn_rollback();
        } );
    };

    return;
}

#--------------------------------------------------------------
