package XT::Rules::Definitions; ## no critic(ProhibitExcessMainComplexity)

use strict;
use warnings;

use Try::Tiny;
use Carp;
use feature ':5.10';

use XTracker::Config::Local     qw{ :DEFAULT get_shipping_restriction_actions_by_type };
use XTracker::Constants::FromDB qw{ :carrier :sub_region :country :ship_restriction :department};
use XT::Service::Designer;
use XTracker::Database          qw{ xtracker_schema };

# Class where we define our rule definitions, for now. This will almost certainly
# change in the future, but works for now.

our %rules = (
    'Configuration::DC' => {
        type => 'configuration',
        output => 'dc_name',
        body => sub {
            my ( $s, $c, $environment ) = @_;
            return $environment->{'config_var'}('DistributionCentre', 'name');
        },
    },
    'Printing::MeasurementForm' => {
        type => 'business',
        configuration => ['Configuration::DC'],
        output => 'Bool',
        body => sub {
            my ( $s, $c ) = @_;
            # Only DC1 requires measuring
            return $c->{'Configuration::DC'} eq 'DC1';
        },
    },
    'PrintFunctions::small_label_template' => {
        type => 'business',
        situation => ['print_language','printer_name'],
        configuration => ['Configuration::DC'],
        output => 'small_label_template',
        body => sub {
            my ( $s, $c ) = @_;
            SMARTMATCH: {
                use experimental 'smartmatch';
                given ( $s->{'print_language'} ) {
                    when ( 'EPL2' ) {
                        return '
q400
N
B*bar_x*,50,0,1,2,4,50,B,"*sku*"
A*size_x*,160,0,2,1,1,N,"*size*"
P*count*
';
                    }
                    when ( 'ZPL' ) {
                    return '
^XA
^BY1,2,10
^FO060,155^A0N,26,26^FDSize: *size*^FS
^FO060,025^BCN,70,N,N^FD*sku*^FS
^FO060,120^A0N,28,28^FD*sku*^FS
^PQ*count*^FS
^XZ
';
                    }
                    default {
                        croak "Printer " . $s->{'printer_name'} . " is not a label printer (according to the configuration file)";
                    }
                }
            }
        }
    },
    'PrintFunctions::large_label_template' => {
        type => 'business',
        situation => ['print_language','printer_name'],
        configuration => ['Configuration::DC'],
        output => 'large_label_template',
        body => sub {
            my ( $s, $c ) = @_;
            use DateTime;
            my $dt      = DateTime->now( time_zone => "local" );
            my $date    = $dt->month.'-'.$dt->day.'-'.$dt->year;
            SMARTMATCH: { # this formatting is too painful to tidy up (CCW)
            use experimental 'smartmatch';
            given ( $s->{'print_language'} ) {
                when ( 'EPL2' ) {
                    return "
q900
N
B*bc_x*,60,0,1,4,8,90,N,\"*sku*\"
A*sku_x*,170,0,5,1,1,N,\"*sku*\"
A*col_x*,320,0,4,1,1,N,\"*colour*\"
A*size_x*,320,0,4,1,1,N,\"*size*\"
A*designer_x*,320,0,4,1,1,N,\"*designer*\"
A*season_x*,350,0,4,1,1,N,\"*season*\"
A10,350,0,4,1,1,N,\"$date\"
P*count*
";
                }
                when ( 'ZPL' ) {
                    given ( $c->{'Configuration::DC'} ) {
                        when ( 'DC1' ) {
                            return '
^XA
^MUd,200,300
^FO430,120^A0N,32,32^FD*designer*^FS
^FO430,160^A0N,28,28^FD*season*^FS
^FO430,200^A0N,28,28^FD*colour*^FS
^FO430,240^A0N,28,28^FD*size*^FS
^FO100,120^BCN,120,N,N^FD*sku*^FS
^FO100,260^A0N,42,42^FD*sku*^FS
^PQ*count*^FS
^XZ
';
                        }
                        when ([ 'DC2','DC3' ]) {
                            given ( $s->{'printer_name'} ) {
                                when ( /Returns\sQC\sLarge\s\d+/ ) {
                                    return "
^XA
^MUd,200,300
^FO445,125^A0N,36,36^FD*designer*^FS
^FO445,165^A0N,32,32^FD*season*^FS
^FO445,205^A0N,32,32^FD*colour*^FS
^FO445,245^A0N,32,32^FD*size*^FS
^FO445,285^A0N,32,32^FD$date^FS
^FO100,120^BCN,150,N,N^FD*sku*^FS
^FO100,285^A0N,75,60^FD*sku*^FS
^PQ*count*^FS
^XZ
";
                                }
                                default {
                                    return '
^XA
^MUd,200,300
^FO445,125^A0N,36,36^FD*designer*^FS
^FO445,165^A0N,32,32^FD*season*^FS
^FO445,205^A0N,32,32^FD*colour*^FS
^FO445,245^A0N,32,32^FD*size*^FS
^FO100,120^BCN,150,N,N^FD*sku*^FS
^FO100,285^A0N,75,60^FD*sku*^FS
^PQ*count*^FS
^XZ
';
                                }
                            }
                        }
                    }
                }
                default {
                    croak "Printer " . $s->{'printer_name'} . " is not a label printer (according to the configuration file)";
                }
            }
            } # finish SMARTMATCH
        }
    },
    'Carrier::manifest_format' => {
        type => 'business',
        situation => ['carrier_id'],
        configuration => ['Configuration::DC'],
        output => 'manifest_format',
        body => sub {
            my ( $s, $c ) = @_;
            SMARTMATCH: {
                use experimental 'smartmatch';
                given ( $c->{'Configuration::DC'} ) {
                    when ( 'DC2' ) {
                        my @carriers = ( $CARRIER__DHL_EXPRESS, $CARRIER__UPS );
                        return (grep { $s->{carrier_id} == $_ } @carriers) ? 'csv' : q{};
                    }
                    default {
                        return $s->{carrier_id} == $CARRIER__DHL_EXPRESS ? 'dhl' : q{};
                    }
                }
            }
        }
    },
    # Location::location_format has been replaced with NAP::DC::Location::Format::get_formatted_location_name
    # from warehouse-common
    'SetPutawayRTV::validate_location_type' => {
        type => 'business',
        situation => ['floor','stock_type'],
        configuration => ['Configuration::DC'],
        output => 'validate_rtv_stock_location',
        body => sub {
            my ( $s, $c ) = @_;
            SMARTMATCH: {
                use experimental 'smartmatch';
                given ( $c->{'Configuration::DC'} ) {
                    when ( 'DC2' ) {
                        if ( $s->{'floor'} != 4 ) {
                            croak "Please select an 024 $s->{'stock_type'} location for this item.";
                        }
                    }
                    default {
                        return "";
                    }
                }
            }
        }
    },
    'SetPutawayMain::validate_location_type' => {
        type => 'business',
        situation => ['floor','stock_type','is_outnet'],
        configuration => ['Configuration::DC'],
        output => 'validate_main_stock_location',
        body => => sub {
            my ( $s, $c ) = @_;
            SMARTMATCH: {
                use experimental 'smartmatch';
                given ( $c->{'Configuration::DC'} ) {
                    when ( 'DC2' ) {
                        use XTracker::Constants::FromDB qw( :stock_process_type );
                        # in DC2, Fast Track locations are on floor 023
                        if ( $s->{'stock_type'} == $STOCK_PROCESS_TYPE__FASTTRACK ) {
                            if ($s->{'floor'} != 3) {
                                croak "Please select a Fast Track location for this item.";
                            }
                        }
                        else {
                            # in DC2, Main Stock locations are on floor 1 or 2 for all channels
                            # (floor 2 locations due to disappear after 2012-05-17)
                            croak "Please select an 021 or 022 Main Stock location for this item.\n"
                                if ( $s->{floor} != 1 && $s->{floor} != 2 );
                        }
                    }
                    default {
                        return "";
                    }
                }
            }
        }
    },
    'PickSheet::select_printer' => {
        type => 'business',
        situation => [qw<
            Business::config_section
            Shipment::is_premier
            Shipment::is_transfer
            Shipment::is_staff
        >],
        configuration => ['Configuration::DC'],
        output => 'printer',
        body => sub {
            my ( $s, $c ) = @_;
            SMARTMATCH: {
                use experimental 'smartmatch';
                given ( $c->{'Configuration::DC'} ) {
                    # TODO shouldn't really be switching on DC, but on iws/prl phase
                    when ( 'DC1' ) {
                        croak q{No picking sheets for DC1 any more};
                    }
                    default {
                        return 'stock_transfer' if $s->{'Shipment::is_transfer'};

                        # TODO: Annoying NAP hack here as they're not
                        # channelised. We need to do a config change to alter
                        # the NAP picking printers so they have the config_section
                        # tagged onto the end
                        return join q{_},
                            ( $s->{'Shipment::is_premier'} ? 'fast' : 'regular' ),
                            ( $s->{'Shipment::is_staff'} ? 'staff' : 'customer' ),
                            ( $s->{'Business::config_section'} eq 'NAP'
                                ? () : $s->{'Business::config_section'} )
                        ;
                    }
                }
            }
        },
    },

    'Shipment::tax_included' => {
        type            => 'business',
        situation       => [ 'country_record' ],
        configuration   => [ 'Configuration::DC' ],
        output          => 'Bool',
        body            => sub {
            my ( $s, $c ) = @_;

            SMARTMATCH: {
                use experimental 'smartmatch';
                given ( $c->{'Configuration::DC'} ) {

                    when ( 'DC1' ) {
                    # DC1 - UK and EU tax inclusive
                        if ( $s->{country_record}->{id} == $COUNTRY__UNITED_KINGDOM || $s->{country_record}->{sub_region_id} == $SUB_REGION__EU_MEMBER_STATES ) {
                            return 1;
                        } else {
                            return 0;
                        }
                    }

                    when ( 'DC2' ) {
                    # DC2 - US tax inclusive
                        if ( $s->{country_record}->{id} == $COUNTRY__UNITED_STATES ) {
                            return 1;
                        } else {
                            return 0;
                        }
                    }

                    when ( 'DC3' ) {
                    # DC3 - Hong Kong tax inclusive
                        if ( $s->{country_record}->{id} == $COUNTRY__HONG_KONG ) {
                            return 1;
                        }
                        else {
                            return 0;
                        }
                    }

                    default {
                        return 0;
                    }

                }
            }
        },
    },

    'Configuration::ShippingRestrictionActions' => {
        type => 'configuration',
        output => 'HashRef',
        body => sub {
            my ( $s, $c, $environment ) = @_;

            return get_shipping_restriction_actions_by_type( $environment->{'schema'} );
        },
    },

    # get all of the Shipping Charges that are linked to Ship Restrictions and
    # return a Hash Ref keyed by Ship Restrcition Id with a Hash Ref of Charges
    'Configuration::ShipRestrictionsAllowedCharges' => {
        type => 'configuration',
        situation => [ 'channel_id' ],
        output => 'HashRef',
        body => sub {
            my ( $s, $c, $environment ) = @_;

            my $channel_id = $s->{channel_id};

            # get the Singleton Schema connection
            my $schema = xtracker_schema();

            # get all of the Shipping Charges that are linked to Ship Restrictions
            my @recs = $schema->resultset('Public::ShipRestrictionAllowedShippingCharge')->search(
                {
                    'shipping_charge.channel_id' => $channel_id,
                },
                {
                    prefetch => 'shipping_charge',
                }
            )->all;

            my %allowed_charges;
            foreach my $rec ( @recs ) {
                my $restriction_id = $rec->ship_restriction_id;
                my $charge         = $rec->shipping_charge;
                $allowed_charges{ $restriction_id }{ $charge->id } = {
                    $charge->get_columns,
                };
            }

            return \%allowed_charges;
        },
    },

    'Configuration::Channels' => {
        type   => 'configuration',
        output => 'HashRef',
        body   => sub {
            my ( $s, $c, $environment ) = @_;

            # WARNING: A slightly nasty hack follows ...
            # Returns a HashRef of all channels, keyed on Channel ID,
            # containing another HashRef with the channel 'object' and
            # fulfilment_only flag (this is because XT::Rules destroys the
            # schema connection of anything passed around within XT::Rules,
            # due to a deep clone). So be warned that the channel object is
            # detached and you cannot execute any further SQL against it.
            #
            # If you want, you can fix XT::Rules, by completing the unfinished
            # code to deal with instances such as this! See the 'TO DO' comment
            # in XT::Rules::Hash, for why this all goes horribly wrong.

            return {
                map {
                    $_->id => {
                        channel         => $_,
                        fulfilment_only => $_->business->fulfilment_only
                    }
                }
                $environment->{'schema'}->resultset('Public::Channel')->all
            };

        },
    },

    'Shipment::restrictions' => {
        type            => 'business',
        situation       => [ 'product_ref', 'address_ref', 'channel_id' ],
        configuration   => [
            'Configuration::DC',
            'Configuration::ShippingRestrictionActions',
            'Configuration::Channels',
        ],
        output          => 'HashRef',
        body            => sub {
            my ( $s, $c ) = @_;

            my $product_ref     = $s->{product_ref};
            my $address_ref     = $s->{address_ref};
            my $channels        = $c->{'Configuration::Channels'};
            my $channel         = $channels->{ $s->{channel_id} }->{channel};
            my $fulfilment_only = $channels->{ $s->{channel_id} }->{fulfilment_only};

            # this will get a Singleton connection to the Schema
            my $schema = xtracker_schema();

            my $designer_service = XT::Service::Designer->new(
                channel => $channel
            );

            # 'Configuration::ShippingRestrictionActions' is generated from the
            # System Config tables for the group 'ShippingRestrictionActions' if
            # any more types are added please be sure to update the System Config
            # settings to include the new types otherwise this method will fail
            # when they are encountered.
            my $type_to_actions = $c->{'Configuration::ShippingRestrictionActions'};

            # This determines whether the action type should have a notify, or
            # should be silent.
            my @silent_actions = qw(
                silent_restrict
            );

            # any new types should be added here also
            my %type_to_reasons = (
                'CHINESE ORIGIN'         => 'Chinese origin product',
                'CITES'                  => 'CITES product',
                'FISH & WILDLIFE'        => 'Fish & Wildlife product',
                'HAZMAT'                 => 'HAZMAT product',
                'DESIGNER SERVICE ERROR' => 'Designer service error',
                'DESIGNER COUNTRY'       => 'Designer destination country',
                'HAZMAT_LQ'              => 'HAZMAT LQ product',
            );

            my %restricted_products;

            # set-up the flags before processing
            my %action_flags    = (
                # These map directly to actions configured in the database.
                silent_restrict => 0,
                restrict        => 0,
                notify          => 0,
                # This is a special action, that determines if all the
                # restrictions are silent.
                all_silent      => 1,
            );

            # sub routine to set the correct values for
            #   %restricted_products
            #   %action_flags
            # as each product is processed in the foreach
            # loop below
            my $sub_set_product_action_and_reason = sub {
                my ( $product_id, $type )   = @_;

                die "Need both a Product Id and Type passed to the anonymous "
                    . "subroutine 'sub_set_product_action_and_reason' in "
                    . "the Business Rule - 'Shipment::restrictions'"
                            if ( !$product_id || !$type );

                my $action  = $type_to_actions->{ $type };
                die "Couldn't find 'action' for Type: '${type}', has this been configured in the System Config tables?"
                                if ( !$action );

                # set the reason for the restriction first
                my $reason  = $type_to_reasons{ $type };
                die "Couldn't find a 'reason' for Type: '${type}', has this been populated in the 'type_to_reasons' hash?"
                                if ( !$reason );

                # Determine if the action should be silent.
                my $action_is_silent = grep
                    { $_ eq $action }
                    @silent_actions;

                push @{ $restricted_products{ $product_id }{reasons} }, {
                    reason => $reason,
                    silent => $action_is_silent,
                };

                # It's useful to have just the reasons themselves for display purposes.
                push @{ $restricted_products{ $product_id }{reason_descriptions} }, $reason;

                # now work out what the actions should be
                my $actions = $restricted_products{ $product_id }{actions} // {
                    silent_restrict => 0,
                    restrict        => 0,
                    notify          => 0,
                };

                $actions->{ $action }   = 1;
                $actions->{notify}      = 0     if ( $actions->{restrict} );        # set 'notify' to be FALSE if 'restrict' has been set
                $actions->{notify}      = 0     if ( $actions->{silent_restrict} ); # set 'notify' to be FALSE if 'silent_restrict' has been set
                $actions->{restrict}    = 1     if ( $actions->{silent_restrict} ); # set 'restrict' to be TRUE if 'silent_restrict' has been set
                $restricted_products{ $product_id }{actions}    = $actions;

                # also set the global flags for the shipment as a whole
                $action_flags{ $action } = 1;
                $action_flags{notify}    = 0    if ( $action_flags{restrict} );        # set 'notify' to be FALSE if 'restrict' has been set
                $action_flags{notify}    = 0    if ( $action_flags{silent_restrict} ); # set 'notify' to be FALSE if 'silent_restrict' has been set
                $action_flags{restrict}  = 1    if ( $action_flags{silent_restrict} ); # set 'restrict' to be TRUE if 'silent_restrict' has been set

                $action_flags{all_silent} = 0
                    unless $action_is_silent;

                return;
            };

            # RESTRICTION 1
            # Chinese origin products shipping to Turkey or Mexico (and EU countries from DC2)

            # RESTRICTION 2
            # CITES products shipping outside US or to California from DC2 and outside EU from DC1

            # RESTRICTION 3
            # Fish & Wildlife products shipping outside US or to California from DC2

            # RESTRICTION 4
            # HAZMAT products shipping outside US from DC2 (so far only for DC2)

            # RESTRICTION 5
            # Designer country restrictions.

            # RESTRICTION 6
            # HAZMAT LQ (Limited Quantity), for DC1 must be in Allowed Countries list and if
            # in UK can't be a postcode for Northern Ireland or Scotland and other areas

            foreach my $product_id ( keys %{$product_ref} ) {

                my $product = $product_ref->{ $product_id };

                # RESTRICTION 5

                unless ( $fulfilment_only ) {
                # There aren't designer services for every channel.

                    my $restricted_countries;

                    try {
                        $restricted_countries = $designer_service
                            ->get_restricted_countries_by_designer_id( $product->{designer_id} );
                    }
                    catch {
                        $sub_set_product_action_and_reason->( $product_id, 'DESIGNER SERVICE ERROR' );
                    };

                    if (
                        ref ( $restricted_countries ) eq 'ARRAY' &&
                        grep { $_ eq $address_ref->{country_code} } @$restricted_countries
                    ) {
                        $sub_set_product_action_and_reason->( $product_id, 'DESIGNER COUNTRY' );
                    }

                }

                # END OF RESTRICTION 5

                # RESTRICTION 1
                if ( exists $product->{country_of_origin}
                    && $product->{country_of_origin}
                    && $product->{country_of_origin} eq 'China' ) {
                    if ( $address_ref->{country} eq 'Mexico' ) {
                        $sub_set_product_action_and_reason->( $product_id, 'CHINESE ORIGIN' );
                    }
                }

                SMARTMATCH: {
                    use experimental 'smartmatch';
                    given ( $c->{'Configuration::DC'} ) {

                        when ( 'DC1' ) {

                            # RESTRICTION 2
                            if ( $product->{cites_restricted} ) {
                                if ( $address_ref->{sub_region} ne 'EU Member States' ) {
                                    $sub_set_product_action_and_reason->( $product_id, 'CITES' );
                                }
                            }

                            # RESTRICTION 6
                            if ( $product->{ship_restriction_ids}{ $SHIP_RESTRICTION__HZMT_LQ } ) {
                                my $product = $schema->resultset('Public::Product')->find( $product_id );
                                my $is_restricted = $product->is_excluded_from_location( {
                                    ship_restriction_id => $SHIP_RESTRICTION__HZMT_LQ,
                                    country             => $address_ref->{country},
                                    postcode            => $address_ref->{postcode},
                                } );
                                if ( $is_restricted ) {
                                    $sub_set_product_action_and_reason->( $product_id, 'HAZMAT_LQ' );
                                }
                            }

                        }

                        when ( 'DC2' ) {

                            # RESTRICTION 2
                            if ( $product->{cites_restricted} ) {
                                if ( $address_ref->{country} ne 'United States' || uc( $address_ref->{county} ) eq 'CA' ) {
                                    $sub_set_product_action_and_reason->( $product_id, 'CITES' );
                                }
                            }

                            # RESTRICTION 3
                            if ( $product->{fish_wildlife} ) {
                                if ( $address_ref->{country} ne 'United States' || uc( $address_ref->{county} ) eq 'CA' ) {
                                    $sub_set_product_action_and_reason->( $product_id, 'FISH & WILDLIFE' );
                                }
                            }

                            # RESTRICTION 4
                            if ( $product_ref->{ $product_id }{is_hazmat} ) {
                                if ( $address_ref->{country} ne 'United States' ) {
                                    $sub_set_product_action_and_reason->( $product_id, 'HAZMAT' );
                                }
                            }

                        }

                        when ( 'DC3' ) {

                            # FIXME APAC: We need Confirmation of the following logic for DC3, CANDO-1884

                            # RESTRICTION 2
                            if ( $product->{cites_restricted} ) {
                                if ( $address_ref->{country} ne 'Hong Kong' ) {
                                    $sub_set_product_action_and_reason->( $product_id, 'CITES' );
                                }
                            }

                        }

                    }
                }
            }

            # if 'restrict' is TRUE then set 'notify' to be FALSE
            # as it's pointless to notify as restrict means the
            # product won't be going to the destination anyway
            $action_flags{notify}   = 0     if ( $action_flags{restrict} );

            # If there are no restricted products, then all_silent being
            # set to TRUE makes no sense.
            $action_flags{all_silent} = 0
                unless scalar keys %restricted_products;

            return {
                restricted_products => \%restricted_products,
                %action_flags,
            };
        },
    },

    'Shipment::exclude_shipping_charges_on_restrictions' => {
        type            => 'business',
        situation       => [
                            'shipping_charges_ref',
                            'shipping_attributes',
                            'always_keep_sku',
                            'channel_id',
                           ],
        configuration   => [ 'Configuration::DC', 'Configuration::ShipRestrictionsAllowedCharges' ],
        output          => 'HashRef',
        body            => sub {
            my ( $s, $c )   = @_;

            my $charges         = $s->{shipping_charges_ref};
            my $attributes      = $s->{shipping_attributes};
            my $always_keep_sku = $s->{always_keep_sku} // "";
            my $allowed_charges = $c->{'Configuration::ShipRestrictionsAllowedCharges'};

            # there are two ways to filter the Shipping Charges
            # either by excluding some Charges based on the value
            # of on of the Shipping Charge fields such as 'class'
            # or by only including some of the Charges, use both
            # techniques if you want but be careful they don't
            # cancel each other out

            # this will contain Shipping Charge fields that
            # will be used to exclude some Shipping Charges
            my %exclude_fields;

            # this will contain the Shipping Charges that can be used
            my %include_only_charges;
            my $only_include_charges = 0;

            my %new_charges     = %{ $charges };
            SMARTMATCH: {
                use experimental 'smartmatch';
                given ( $c->{'Configuration::DC'} ) {
                    when ( 'DC1' ) {
                        foreach my $attrib ( values %{ $attributes } ) {
                            # check for LQ Hazmat Restriction
                            if ( $attrib->{ship_restriction_ids}{ $SHIP_RESTRICTION__HZMT_LQ } ) {
                                if ( my $restrict_charges = $allowed_charges->{ $SHIP_RESTRICTION__HZMT_LQ } ) {
                                    %include_only_charges = (
                                        %include_only_charges,
                                        %{ $restrict_charges },
                                    );
                                    $only_include_charges = 1;
                                }
                            }
                        }
                    }

                    when ( 'DC2' ) {
                        # nothing so far
                    }

                    when ( 'DC3' ) {
                        # nothing so far
                    }
                }
            }

            CHARGE:
            foreach my $id ( keys %new_charges ) {
                my $charge  = $new_charges{ $id };
                next CHARGE     if ( $always_keep_sku eq $charge->{sku} );

                my $exclude = 0;
                while ( my ( $field, $value ) = each %exclude_fields ) {
                    if ( $charge->{ $field } && ( lc( $charge->{ $field } ) eq lc( $value ) ) ) {
                        $exclude    = 1;
                    }
                }
                delete $new_charges{ $id }      if ( $exclude );

                if ( $only_include_charges ) {
                    delete $new_charges{ $id }      if ( !exists( $include_only_charges{ $id } ) );
                }
            }

            return \%new_charges;
        },
    },

    #
    # Will return TRUE or FALSE depending on whether a Postcode matches against any of a list of Postcodes.
    # If the Country is for the U.K. then we need to remove the last 3 characters of the Postcode so long as
    # they match the pattern Digit, followed by 2 Letters at the end of the postcode, then if the postcode
    # we're checking it against ends in a number we do an exact match (eq) otherwise we do a pattern match
    # rooting to the beginning followed by a digit (/^pcode_to_check_against\d/).
    #
    # For Non U.K. Countries this will be a simple case insensative comparison. When other countries Postcodes
    # are required to be matched against then their Rules can be added to this Definition.
    #
    'Address::is_postcode_in_list_for_country' => {
        type            => 'business',
        situation       => [ 'postcode', 'country_id', 'postcode_list' ],
        configuration   => [],
        output          => 'Bool',
        body            => sub {
            my ( $s, $c ) = @_;

            my $country_id = $s->{country_id};
            my $postcode   = uc( $s->{postcode} // '' );
            my $pcode_list = $s->{postcode_list} // [];

            # remove any whitespace in the postcode
            $postcode =~ s/\s//g;

            if ( $country_id == $COUNTRY__UNITED_KINGDOM ) {
                # remove the last 3 characters of the Postcode but
                # only if they are a digit followed by two letters
                $postcode =~ s/\d[A-Z]{2}$//;

                foreach my $pcode_to_check ( @{ $pcode_list } ) {
                    $pcode_to_check = uc( $pcode_to_check );
                    if ( $pcode_to_check =~ /\d$/ ) {
                        return 1    if ( $postcode eq $pcode_to_check );
                    }
                    else {
                        return 1    if ( $postcode =~ m/^${pcode_to_check}\d/ );
                        return 1    if ( $postcode eq $pcode_to_check );
                    }
                }

                return 0;
            }

            my $found =  scalar grep {
                $postcode eq uc( $_ )
            } @{ $pcode_list };

            return ( $found ? 1 : 0 );
        },
    },

    'Database::Pricing::product_selling_price::vertext_workaround' => {
        type            => 'business',
        situation       => [ 'country', 'county' ],
        configuration   => [ 'Configuration::DC' ],
        output          => 'Bool',
        body            => sub {
            my ( $s, $c ) = @_;

            SMARTMATCH: {
                use experimental 'smartmatch';
                given ( $c->{'Configuration::DC'} ) {
                    when ( 'DC1' ) { return 0 }
                    when ( 'DC2' ) {
                        if ( $s->{country} eq 'United States' && $s->{county} eq 'NY' ) {
                            return 1;
                        }
                    }
                    when ( 'DC3' ) { return 0 }
                }
            }
        },
    },
    # Will return the VALUE [ 1 or 0 ] to be set for signature_required flag when shipment address is updated.
    # Changing shipping address by Shipping Department does not update the flag.
    # Also for DC2, If the country is US the flag is not updated.
    # for all other instances the flag is set to TRUE.
    'Shipment::get_allowed_value_of_shipment_signature_required_flag_for_address' => {
        type            => 'business',
        situation       => [ 'department_id', 'signature_required_flag', 'address_ref' ],
        configuration   => [ 'Configuration::DC' ],
        output          => 'Bool',
        body            => sub {
            my ($s, $c ) = @_;

            my $dept_id  = $s->{department_id};
            my $sig_flag = $s->{signature_required_flag};
            my $country  = $s->{address_ref}->{country};

             # Rule 1: check for department
             if( $dept_id =~ /^(
                $DEPARTMENT__SHIPPING|
                $DEPARTMENT__SHIPPING_MANAGER)$/x ) {
                    return $sig_flag;
             }

             # Rule 2 : Check DC/country
             SMARTMATCH: {
                use experimental 'smartmatch';
                given ( $c->{'Configuration::DC'} ) {
                    when ( [ 'DC1', 'DC3'] ) {
                            return 1;
                    }
                    when ( 'DC2' ) {
                        if ( $country eq 'United States' ) {
                            return $sig_flag;
                        } else {
                            return 1;
                        }
                    }
                }
            }

        },

    },
);

1;

__DATA__

    'Shipment::sticker_count' => {
        type => 'business',
        situation     => [qw/
            channel_id
            shipment_is_real_order
            shipment_item_count
            order_sticker_text
        /],
        configuration => [ 'Channel::supports_stickers' ],
        output        => 'Int',
        body          => sub {
            my ( $s, $c ) = @_;

            # We don't print any stickers unless it's a shipment belonging to
            # a real order, there are shipment items, and we have sticker text
            # attached to the order - and if the channel supports stickers
            return 0 unless
                $s->{'shipment_is_real_order'} &&
                $s->{'shipment_item_count'}    &&
                $s->{'order_sticker_text'}     &&
                $c->{'Channel::supports_stickers'};

            return $s->{'shipment_item_count'};
        }
    },
    'Channel::supports_stickers' => {
        type      => 'configuration',
        situation => ['channel_id'],
        output    => 'Bool',
        body      => sub {
            my ( $situation, $configuration, $environment ) = @_;

            $environment->{'schema'}
                ->resultset('SystemConfig::ConfigGroupSetting')->config_var(
                    "personalized_stickers", "print_sticker",
                    $situation->{'channel_id'}
                );
        }
    }
);

1
