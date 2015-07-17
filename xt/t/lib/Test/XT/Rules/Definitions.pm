package Test::XT::Rules::Definitions;

use NAP::policy "tt", 'test';
use Carp;
use feature ':5.10';

use Test::More;


use XTracker::Config::Local;
use XTracker::Constants::FromDB qw( :flow_status :country :business :ship_restriction );

=pod

Class where we define our rule definitions, for now. This will almost certainly
change in the future, but works for now.

    %rules = (
        'Rule::Name' => {
            type            => '',          # Either 'business' or 'configuration'.
            situation       => [ '', ... ], # String values - Names of parameters, that have matching Type constraints.
            configuration   => [ '', ... ], # String values - Names of previously defined rules of type configuration.
            output          => '',          # String value  - Name of a defined Type constraint.
            body            => sub { ... }, # A subroutine reference that's passed $situation and $configuration.
        },
    );

Example

    %rules = (

        'Configuration::DC' => {
            type    => 'configuration',
            output  => 'dc_name',
            body    => sub {
                my ( $s, $c, $environment ) = @_;
                return $environment->{'config_var'}('DistributionCentre', 'name');
            },
        },


        'My::Rule' => {
            type            => 'business',
            situation       => [ 'parameter_1', 'parameter_2' ],
            configuration   => [ 'Configuration::DC' ],
            output          => 'my_defined_type',
            body            => sub {
                my ( $situation, $configuration ) = @_;
                use experimental 'smartmatch';
                given ( $configuration->{'Configuration::DC'} ) {
                    when ( 'DC1' ) {
                        return $situation->{'parameter_1'} + $situation->{'parameter_2'};
                    }
                    when ( 'DC2' ) {
                        return $situation->{'parameter_1'} * $situation->{'parameter_2'};
                    }
                    default {
                        return undef;
                    }
                }
            },
        },

    );

=cut

our %rules = (

    'Configuration::DC' => {
        type    => 'configuration',
        output  => 'dc_name',
        body    => sub {
            my ( $s, $c, $environment ) = @_;
            return $environment->{'config_var'}('DistributionCentre', 'name');
        },
    },

    'Configuration::Schema' => {
        type    => 'configuration',
        output  => 'schema',
        body    => sub {
            my ( $s, $c, $environment ) = @_;
            return $environment->{'schema'};
        },
    },


    'XTracker::Data::SetProductStock::ApplyChannelisation' => {
        type            => 'business',
        situation       => [ 'stock_status_type', 'locations' ],
        configuration   => [ 'Configuration::DC', 'Configuration::Schema' ],
        output          => 'locations',
        body            => sub {
            my ( $s, $c ) = @_;
            return $s->{locations}->get_locations({ floor => 4 })
                if $c->{'Configuration::DC'} eq 'DC2'
                && $s->{stock_status_type} != $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;

            return $s->{locations};
        }
    },


    'XTracker::Data::ShipmentValidity' => {
        type            => 'business',
        situation       => [ 'shipment', 'validity' ],
        configuration   => [ 'Configuration::DC' ],
        output          => 'Undef',
        body            => sub {
            my ( $s, $c ) = @_;

            my $shipment = $s->{shipment};
            if ( $shipment->carrier_is_ups ) {
                $shipment->update({
                    destination_code  => undef,
                    av_quality_rating => $s->{validity} ? 100 : 0,
                });
                return;
            }
            if ( $shipment->carrier_is_dhl ) {
                # I don't think the actual code is that important, but let's
                # pick the 'default' one for each DC
                my $destination_code = {
                    DC1 => 'LHR',
                    DC2 => 'NYC',
                    DC3 => 'HKG',
                }->{$c->{'Configuration::DC'}} or die sprintf
                    'XTracker::Data::ShipmentValidity: Unknown DC %s',
                    $c->{'Configuration::DC'};

                $shipment->update({
                    av_quality_rating => undef,
                    # Not sure about rtcb... let's turn it off for now
                    real_time_carrier_booking => 0,
                    destination_code => $s->{validity} ? $destination_code : undef,
                });
                return;
            }
        },
    },

    'XTracker::Client::TranslateLocation' => {
        type            => 'business',
        situation       => [ 'packing_location' ],
        configuration   => [ 'Configuration::DC' ],
        output          => 'Str',
        body            => sub {
            my ( $s, $c ) = @_;

            my $location = $s->{'packing_location'};

            if ( not $location =~ m{\d} ) {
                # it does contain a digit, it's probably not a shelf or
                # similar, don't add prefixes
                return $location;
            }

            $location =~ s/-//g;

            # Convert to the proper location type. DC2 ones have a slightly different
            # format with a hyphen in them:
            # DC2 eg: 021D-0015C
            # DC1 eg: 012J297C
            SMARTMATCH: {
                use experimental 'smartmatch';
                given ( $c->{'Configuration::DC'} ) {

                    when ( 'DC1' ) {

                        $location = '01' . $location;

                    }

                    when ( 'DC2' ) {

                        # As of DC2.5 we have more than 1 floor, so '021' doesn't cut it. If
                        # we pass 'new' floor types (i.e. they start with a floor number), we
                        # need to parse this differently.
                        my $dc_loc = $location =~ m{^(\d+)} ? '02' : '021';
                        $location = $dc_loc . $location;
                        # Insert the DC2 hyphen
                        $location =~ s/^(\d{3}\w)(.*)/$1-$2/;

                    }

                    when ( 'DC3' ) {

                        # DC3 location layout is, for now, assumed to be
                        # the same as DC2; this may well turn out to be
                        # wrong
                        # Update (30/11/2012): Business does not seem to have any plans to change location format
                        my $dc_loc = $location =~ m{^(\d+)} ? '03' : '031';
                        $location = $dc_loc . $location;
                        # Insert the DC3 hyphen
                        $location =~ s/^(\d{3}\w)(.*)/$1-$2/;

                    }

                }
            }

            return $location;

        },
    },

    'XTracker::Data::Email::SurveyLink' => {
        type            => 'business',
        situation       => [ 'content' ],
        configuration   => [ 'Configuration::DC' ],
        output          => 'Bool',
        body            => sub {
            my ( $s, $c ) = @_;

            SMARTMATCH: {
                use experimental 'smartmatch';
                given ( $c->{'Configuration::DC'} ) {

                    when ( 'DC1' ) {

                        my $survey_link = 'Please click on the link to take part in our short survey http://www.snapsurveys.com';
                        unlike( $s->{'content'}, qr/.*$survey_link.*/s, "No Survey Link");

                    }

                    # FIXME: APAC What to do for DC3?
                    when ( [ 'DC2', 'DC3' ] ) {

                        my $start_point = 'Please click on the link to take part in our short survey';
                        my $survey_link = "http://www.snapsurveys.com";
                        like( $s->{'content'}, qr/$start_point.*$survey_link.*/s, "Survey Link is correct");

                    }

                }
            }
        },
    },

    'XTracker::Mechanize::AirwayBill' => {
        type            => 'business',
        situation       => [ 'framework', 'mechanize' ],
        configuration   => [ 'Configuration::DC' ],
        output          => 'Undef',
        body            => sub {
            my ( $s, $c ) = @_;

            SMARTMATCH: {
                use experimental 'smartmatch';
                given ( $c->{'Configuration::DC'} ) {

                    when ( [qw/DC1 DC3/] ) {

                        if ( grep { $_->{attr}{name} && $_->{attr}{name} eq "waybillForm" } @{ $s->{'mechanize'}->forms } ) {
                            my ( $awb ) = Test::XTracker::Data->generate_air_waybills;
                            $s->{'framework'}->flow_mech__fulfilment__packing_packshipment_submit_waybill(
                                $awb
                            );
                        }

                    }

                }
            }

            return;

        },
    },

    'XTracker::Mechanize::OtherLocations' => {
        type            => 'business',
        situation       => [ 'location', 'locations' ],
        configuration   => [ 'Configuration::DC' ],
        output          => 'locations',
        body            => sub {
            my ( $s, $c ) = @_;

            SMARTMATCH: {
                use experimental 'smartmatch';
                given ( $c->{'Configuration::DC'} ) {

                    when ( [ 'DC2', 'DC3' ] ) {

                        # if location has a floor, find other locations on the same floor
                        if ( my $floor = $s->{'location'}->floor ) {
                            return $s->{'locations'}->get_locations({ floor => $floor });
                        }

                    }

                }
            }

            return $s->{'locations'};

        }
    },

    # gives the Shipping Attribute to change and part of the Address
    # to change to make a Product/Address Restricted.
    # IT IS NOT ALL THE CONDITIONS THAT GET RESTRICTED JUST SOME
    'Shipment::restrictions'    => {
        type            => 'business',
        situation       => [ 'restriction' ],
        configuration   => [ 'Configuration::DC' ],
        output          => 'HashRef',
        body            => sub {
            my ( $s, $c )   = @_;

            my $restriction = $s->{restriction};
            my $dc      = $c->{'Configuration::DC'};

            # used 'Mexico' a lot so there can
            # be overlaps with multiple restrictions
            my %data    = (
                CITES   => {
                    shipping_attribute => {
                        # change to product
                        cites_restricted    => 1,
                    },
                    address => {
                        DC1 => {
                            # NON EU
                            country => 'Mexico',
                        },
                        DC2 => {
                            # Not the USA
                            country => 'Mexico',
                        },
                        DC3 => {
                            # Not Hong Kong
                            country => 'Mexico',
                        },
                    },
                },
                HAZMAT  => {
                    shipping_attribute => {
                        is_hazmat   => 1,
                    },
                    address => {
                        DC1 => {
                            # nothing so far
                        },
                        DC2 => {
                            # Not the USA
                            country => 'Mexico',
                        },
                        DC3 => {
                            # nothing so far
                        },
                    },
                },
                FISH_WILDLIFE => {
                    shipping_attribute => {
                        fish_wildlife   => 1,
                    },
                    address => {
                        DC1 => {
                            # nothing
                        },
                        DC2 => {
                            # Not the USA
                            country => 'Mexico',
                        },
                        DC3 => {
                            # nothing
                        },
                    },
                },
                CHINESE_ORIGIN => {
                    shipping_attribute => {
                        country_id  => $COUNTRY__CHINA,
                    },
                    address => {
                        DC1 => {
                            country => 'Mexico',
                        },
                        DC2 => {
                            country => 'Mexico',
                        },
                        DC3 => {
                            country => 'Mexico',
                        },
                    },
                },
                LQ_HAZMAT => {
                    shipping_attribute => { },
                    ship_restriction   => [
                        $SHIP_RESTRICTION__HZMT_LQ,
                    ],
                    address => {
                        DC1 => {
                            # nowhere near Europe
                            country => 'Australia',
                        },
                        DC2 => {
                            # nothing so far
                        },
                        DC3 => {
                            # nothing so far
                        },
                    },
                },
            );

            my $attribute        = $data{ $restriction }{shipping_attribute};
            my $address          = $data{ $restriction }{address}{ $dc };
            my $ship_restriction = $data{ $restriction }{ship_restriction};

            return {
                ( $attribute        ? ( shipping_attribute => $attribute )      : () ),
                ( $address          ? ( address => $address )                   : () ),
                ( $ship_restriction ? ( ship_restriction => $ship_restriction ) : () ),
            };
        },
    },

    # gives the From Address based on Sales Channel
    # that should be in the 'shipping_account' table
    'ShippingAccount::FromCompanyName'  => {
        type            => 'business',
        situation       => [ 'business_id' ],
        configuration   => [ 'Configuration::DC' ],
        output          => 'Str',
        body            => sub {
            my ( $s, $c )   = @_;

            my $business_id = $s->{business_id};
            my $dc          = $c->{'Configuration::DC'};

            my %company_names   = (
                DC1 => {
                    $BUSINESS__NAP      => 'NET-A-PORTER',
                    $BUSINESS__OUTNET   => 'THE OUTNET',
                    $BUSINESS__MRP      => 'MRPORTER',
                    $BUSINESS__JC       => 'JC',
                },
                DC2 => {
                    $BUSINESS__NAP      => 'NET-A-PORTER',
                    $BUSINESS__OUTNET   => 'THE OUTNET',
                    $BUSINESS__MRP      => 'MRPORTER',
                    $BUSINESS__JC       => 'JC',
                },
                DC3 => {
                    $BUSINESS__NAP      => 'The NET-A-PORTER Group Asia Pacific',
                },
            );

            my $name    = $company_names{ $dc }{ $business_id };
            croak "Couldn't find a 'From Company Name' for DC: '${dc}', Business Id: '${business_id}'"
                        if ( !$name );

            return $name;
        },
    },

);

1;
