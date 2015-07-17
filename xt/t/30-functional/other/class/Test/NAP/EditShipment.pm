package Test::NAP::EditShipment;

=head1 NAME

Test::NAP::EditShipment

=head1 DESCRIPTION

This tests EditShipment and UpdateShipment, both on the unit level and
by calling the test server.

Note that some of these tests don't use mech, and should be moved to a non-mech
location.

#TAGS editshipment shouldbeunit nominatedday

=cut

use NAP::policy qw/class test/;

BEGIN { extends 'NAP::Test::Class'; };

use Test::XTracker::RunCondition( export => qw( $distribution_centre ) );

use Data::Printer;
use HTML::Form::Extras;

use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Data::Shipping;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :customer_category
    :renumeration_class
    :renumeration_status
    :renumeration_type
    :shipment_item_status
    :shipment_status
    :shipment_type
    :shipping_charge_class
    :ship_restriction
);
use XTracker::Config::Local qw( config_var );

use XTracker::Database::Address;
use XTracker::Database::Shipment qw(
    get_address_shipping_charges
    get_shipment_info
    get_shipment_item_info
);

use XTracker::Order::Functions::Shipment::EditShipment;
use XTracker::Order::Actions::UpdateShipment;

use XT::Net::WebsiteAPI::TestUserAgent;
use XT::Net::WebsiteAPI::Response::AvailableDate;

sub startup : Tests {
    my $self = shift;

    my $framework = $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            "Test::XT::Flow::Fulfilment",
            "Test::XT::Flow::CustomerCare",
            'Test::XT::Data::Order',
        ],
    );
    $framework->login_with_permissions({
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                "Customer Care/Order Search",
                "Customer Care/Customer Search",
            ],
        },
        dept => "Distribution Management", # Important for the EditShipment page
    });
    $framework->mech->force_datalite(1);

    $self->{channel} = Test::XTracker::Data->channel_for_nap();
}

# 2011-09-16* ==> 16-09-2011*
sub to_web_date_format {
    my ($iso_dt) = @_;
    return $iso_dt =~ s|(\d+)-(\d+)-(\d+)(.*)|$3-$2-$1$4|r;
}

# 2011-09-16* ==> 16/09/2011*
sub to_legacy_web_date_format {
    my (@iso_dts) = @_;
    return map { s|(\d+)-(\d+)-(\d+)(.*)|$3/$2/$1$4|r } @iso_dts;
}

sub as_available_date {
    my ($date) = @_;
    return XT::Net::WebsiteAPI::Response::AvailableDate->new({
        delivery_date => $date,
    });
}

sub as_full_available_date {
    my ($date) = @_;
    return XT::Net::WebsiteAPI::Response::AvailableDate->new({
        delivery_date => $date,
        dispatch_date => $date,
    });
}

sub ymd {
    my ($datetime) = @_;
    $datetime or return $datetime;
    return $datetime->ymd;
}

sub non_premier_shipping_charge {
    my $self = shift;

    my $non_premier_shipping_charge_sku = {
        # These are valid NAP skus for the current_dc address
        DC1 => "900003-001",
        DC2 => "900065-002",
        DC3 => "9000311-001",
    }->{$distribution_centre} or die("Unknown DC ($distribution_centre)");

    return $self->schema->resultset("Public::ShippingCharge")->search({
        sku        => $non_premier_shipping_charge_sku,
        channel_id => $self->{channel}->id,
    })->first;
}

# 'Courier Special Delivery' should be available
# if not default to non-premier shipping charge
sub courier_shipping_charge {
    my $self = shift;
    return $self->schema->resultset("Public::ShippingCharge")->search( {
        channel_id  => $self->{channel}->id,
        description => 'Courier Special Delivery',
    } )->first // $self->non_premier_shipping_charge;
}

# get all the Premier Routing recs by Code
sub premier_routing_recs {
    my $self = shift;
    return {
        map { $_->code => $_ }
        $self->schema->resultset('Public::PremierRouting')->all
    };
}

sub premier_routing {
    my $self = shift;

    my $premier_routing_recs = $self->premier_routing_recs;
    # Daytime
    return {
        id          => $premier_routing_recs->{D}->id,
        description => $premier_routing_recs->{D}->description,
    };
}

sub other_premier_routing {
    my $self = shift;

    my $premier_routing_recs = $self->premier_routing_recs;
    # Evening
    return {
        id          => $premier_routing_recs->{E}->id,
        description => $premier_routing_recs->{E}->description,
    };
}

sub premier_shipping_charge {
    my $self = shift;
    return Test::XTracker::Data::Order->get_premier_shipping_charge(
        $self->{channel},
        $self->premier_routing,
    );
}

sub other_premier_shipping_charge {
    my $self = shift;
    Test::XTracker::Data::Order->get_premier_shipping_charge(
        $self->{channel},
        $self->other_premier_routing,
    );
}

# Test the mapping between shipping charge and premier routing
sub test_delivery_option : Tests {
    my ( $self ) = @_;

    my $test_cases = [
        {
            description => "Not Premier",
            setup       => {
                carrier_name       => config_var("DistributionCentre", "default_carrier"),
                shipment_type      => $SHIPMENT_TYPE__DOMESTIC,
                shipping_charge_id => $self->non_premier_shipping_charge->id,
            },
            expected => {
                shipping_option => {
                    DC1 => sub {
                        my ($shipping_option) = @_;
                        _test_shipping_option(
                            $shipping_option,
                            # DC1 example:
                            # "--------------Courier Special DeliveryUK Express"
                            "Courier Special DeliveryUK Express",
                            # DC1 example: "UK Express"
                            "UK Express",
                        );
                    },
                    DC2 => sub {
                        my ($shipping_option) = @_;
                        _test_shipping_option(
                            $shipping_option,
                            # DC2 example:
                            # "--------------Kentucky 3-5 Business DaysKentucky Next Business Day"
                            "Kentucky 3-5 Business DaysKentucky Next Business Day",
                            # DC2 example: "Kentucky 3-5 Business Days"
                            "Kentucky 3-5 Business Days",
                        );
                    },
                    DC3 => sub {
                        my ($shipping_option) = @_;
                        _test_shipping_option(
                            $shipping_option,
                            'Domestic'
                        );
                    },
                }->{$distribution_centre},
                delivery_option => "",
            },
        },
        {
            # currently DC2 is the only one that has this restriction
            description => "HAZMAT Restriction removed for Air",
            setup       => {
                carrier_name       => config_var("DistributionCentre", "default_carrier"),
                shipment_type      => $SHIPMENT_TYPE__DOMESTIC,
                shipping_charge_id => $self->non_premier_shipping_charge->id,
            },
            expected => {
                shipping_option => {
                    DC1 => sub {
                        my ($shipping_option) = @_;
                        _test_shipping_option(
                            $shipping_option,
                            # DC1 example:
                            # "--------------Courier Special DeliveryUK Express"
                            "Courier Special DeliveryUK Express",
                            # DC1 example: "UK Express"
                            "UK Express",
                        );
                    },
                    DC2 => sub {
                        my ($shipping_option) = @_;
                        _test_shipping_option(
                            $shipping_option,
                            # DC2 example:
                            # "--------------Kentucky 3-5 Business DaysKentucky Next Business Day"
                            "Kentucky",
                            # DC2 example: "Kentucky 3-5 Business Days"
                            "Kentucky 3-5 Business Days"
                        );
                    },
                    DC3 => sub {
                        my ($shipping_option) = @_;
                        _test_shipping_option(
                            $shipping_option,
                            "Domestic",
                        );
                    },
                }->{$distribution_centre},
                delivery_option => "",
            },
        },
        {
            # currently DC1 is the only one that has this restriction
            description => "HAZMAT LQ NO Shipping Charge of Class 'Air' should be shown",
            setup       => {
                carrier_name       => config_var("DistributionCentre", "default_carrier"),
                shipment_type      => $SHIPMENT_TYPE__DOMESTIC,
                shipping_charge_id => $self->courier_shipping_charge->id,     # start with Courier
                restrictions       => {
                    ship_restrictions => [
                        $SHIP_RESTRICTION__HZMT_LQ,
                    ],
                },
            },
            expected => {
                shipping_option => {
                    DC1 => sub {
                        my ($shipping_option) = @_;
                        _test_shipping_option(
                            $shipping_option,
                            # "--------------Courier Special DeliveryUK Standard"
                            "Courier Special DeliveryUK Express.*UK Standard",
                            "Courier Special Delivery",
                        );
                    },
                    DC2 => sub {
                        my ($shipping_option) = @_;
                        _test_shipping_option(
                            $shipping_option,
                            # DC2 example:
                            # "--------------Kentucky 3-5 Business DaysKentucky Next Business Day"
                            "Kentucky",
                            # DC2 example: "Kentucky 3-5 Business Days"
                            "Courier Special Delivery",
                        );
                    },
                    DC3 => sub {
                        my ($shipping_option) = @_;
                        _test_shipping_option(
                            $shipping_option,
                            "Domestic",
                        );
                    },
                }->{$distribution_centre},
                delivery_option => "",
            },
        },
        {
            description => "Premier",
            setup => {
                shipment_type      => $SHIPMENT_TYPE__PREMIER,
                carrier_name       => "Unknown", # Premier
                shipping_charge_id => $self->premier_shipping_charge->id,
            },
            expected => {
                shipping_option => sub {
                    my ($shipping_option) = @_;
                    _test_shipping_option(
                        $shipping_option,
                        # DC1 example:
                        # "--------------UK ExpressPremier Daytime - Zone 2Premier Evening - Zone 2"
                        "Premier Daytime",
                        # DC1 example: "Premier Daytime - Zone 2"
                        "Premier Daytime",
                    );
                },
                delivery_option => $self->premier_routing->{description},
            },
        },
    ];

    note("*** Test Delivery Option / Premier Routing");

    for my $case (@$test_cases) {
        subtest $case->{description} => sub {
            my $setup = $case->{setup};
            my $expected = $case->{expected};

            my $shipment = Test::XTracker::Data::Order->create_shipment(
                $self->{channel},
                $setup,
                $self->premier_shipping_charge,
            );
            # make sure the Customer's Category is 'None'
            my $customer = $shipment->order->customer;
            $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );

            Test::XTracker::Data::Order->set_item_shipping_restrictions(
                $shipment,
                $setup->{restrictions},
            );

            my $framework = $self->{framework};
            $framework->flow_mech__customercare__edit_shipment($shipment);

            my $shipping_option_details = $framework->mech->as_data()->{shipping_option};
            my $expected_shipping_option = $expected->{shipping_option};
            if(ref($expected_shipping_option) eq "CODE") {
                $expected_shipping_option->(
                    $shipping_option_details->{"Shipping Option"},
                );
            }
            else {
                is(
                    $shipping_option_details->{"Shipping Option"},
                    $expected_shipping_option,
                    "Shipping Option ok",
                );
            }
            is(
                $shipping_option_details->{"Delivery Option"},
                $expected->{delivery_option},
                "Delivery Option ok",
            );

            Test::XTracker::Data::Order->clear_item_ship_restrictions( $shipment );
        };
    }
}

sub _test_shipping_option {
    my ($shipping_option, $dropdown_contents, $dropdown_selected, $is_not_shown) = @_;
    if( ref( $shipping_option) eq 'HASH' ) {
        is(
            $shipping_option->{select_name},
            "shipping_charge_id",
            "element name ok",
        );
        # DC1 example:
        # "--------------UK ExpressPremier Daytime - Zone 2Premier Evening - Zone 2"
        # DC2 example:
        # "--------------Kentucky 3-5 Business DaysKentucky Next Business Day"
        like(
            $shipping_option->{value},
            qr/^--------------.*?$dropdown_contents/,
            "  and the values look alright",
        );
        # DC1 example: "Premier Daytime - Zone 2"
        # DC2 example: "Kentucky 3-5 Business Days"
        like(
            $shipping_option->{select_selected}->[1],
            qr/^$dropdown_selected/,
            "  and the selected value looks alright",
        );

        if ( $is_not_shown ) {
            unlike(
                $shipping_option->{value},
                qr/$is_not_shown/,
                "and some Charges are NOT shown"
            );
        }
    }
    else {
        is(
            $shipping_option,
            $dropdown_contents,
            "Delivery Option is correct",
        );
    }
}

# Test the different display outcomes for the date/dropdown/error message, etc.
sub nominated_delivery_date { "2011-09-15" }

sub setup_available_delivery_dates {
    return [qw{
        2011-09-13
        2011-09-14
        2011-09-15
        2011-09-16
        2011-09-17
        2011-09-18
    }];
}

sub test_display_nominated_day : Tests {
    my ($self) = @_;

    my $setup_available_delivery_dates = $self->setup_available_delivery_dates;
    my $test_cases = [
        {
            description => "No Nominated Day; don't display the date",
            setup       => {
                carrier_name           => config_var("DistributionCentre", "default_carrier"),
                shipment_type          => $SHIPMENT_TYPE__DOMESTIC,
                shipping_charge_id     => $self->non_premier_shipping_charge->id,
                nominated_delivery_date => undef,
            },
            expected => {
                delivery_date_present => 0,
            },
        },
        {
            description => "Nominated Day, Already selected; display date, but not editable",
            setup => {
                shipment_type           => $SHIPMENT_TYPE__PREMIER,
                carrier_name            => "Unknown", # Premier
                shipping_charge_id      => $self->premier_shipping_charge->id,
                nominated_delivery_date => $self->nominated_delivery_date,
            },
            expected => {
                delivery_date_present => 1,
                delivery_date_string  => "15/09/2011",
            },
        },
        {
            description => "Nominated Day, Not selected; display date combo, editable",
            setup => {
                shipment_type            => $SHIPMENT_TYPE__PREMIER,
                carrier_name             => "Unknown", # Premier
                shipping_charge_id       => $self->premier_shipping_charge->id,
                nominated_delivery_date  => $self->nominated_delivery_date,
                available_delivery_dates => $setup_available_delivery_dates,
                shipment_item_status     => $SHIPMENT_ITEM_STATUS__NEW,
            },
            expected => {
                delivery_date_present            => 1,
                available_delivery_dates         => [
                    to_legacy_web_date_format(@$setup_available_delivery_dates)
                ],
                delivery_date_preselected_string => "15/09/2011",
            },
        },
        {
            description => "Nominated Day, Not selected, Can't call Website; display date, but not editable, and error message",
            setup => {
                shipment_type           => $SHIPMENT_TYPE__PREMIER,
                carrier_name            => "Unknown", # Premier
                shipping_charge_id      => $self->premier_shipping_charge->id,
                nominated_delivery_date => $self->nominated_delivery_date,
                shipment_item_status    => $SHIPMENT_ITEM_STATUS__NEW,
                website_response        => HTTP::Response->new(404 => "Not found"),
            },
            expected => {
                delivery_date_present => 1,
                # Really "15/09/2011", but the data extractor doesn't see
                # the value with the error div there
                delivery_date_string  => undef,
                error_message         => "Couldn't determine available delivery days",
                error_message_detail  => "Not found",
            },
        },
    ];

    note("*** Test Nominated Day");

    for my $case (@$test_cases) {
        subtest $case->{description} => sub {
            my $setup = $case->{setup};
            my $expected = $case->{expected};
            my ($shipment, $response_or_data) = Test::XTracker::Data::Order->create_shipment_and_response(
                $self->{channel},
                $setup,
                $self->premier_shipping_charge,
            );
            # make sure the Customer's Category is 'None'
            my $customer = $shipment->order->customer;
            $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );

            my $framework = $self->{framework};
            XT::Net::WebsiteAPI::TestUserAgent->with_get_response(
                $response_or_data,
                sub {
                    $framework->flow_mech__customercare__edit_shipment($shipment);
                },
            );

            my $page_shipping_option = $framework->mech->as_data()->{shipping_option};
            my $page_nominated_delivery_date = $page_shipping_option->{"Nominated Delivery Date"};

            if($expected->{delivery_date_present}) {
                ok( $page_nominated_delivery_date, "Delivery Date is present" );
                if(my $delivery_date_string = $expected->{delivery_date_string}) {
                    is(
                        $page_nominated_delivery_date,
                        $delivery_date_string,
                        "Not editable, got a scalar date string",
                    );
                }

                if(my $expected_delivery_dates = $expected->{available_delivery_dates}) {
                    is(
                        $page_nominated_delivery_date,
                        join(
                            "",
                            @$expected_delivery_dates,
                        ),
                        "Expected delivery dates present in combo dropdown",
                    );
                }
                # If we could: test the
                # $expected->{delivery_date_preselected_string}, but this
                # parsing doesn't expose that.

                if(my $error_message = $expected->{error_message}) {
                    like(
                        $page_nominated_delivery_date,
                        qr/$error_message/,
                        "Expected error message present",
                    );
                }


                # also test the other things
            }
            else {
                ok(
                    !$page_nominated_delivery_date,
                    "Delivery Date is NOT present",
                );
            }
        };
    }
}

# Test the different outcomes: Ok update, don't update, die with error message
sub different_valid_new_nominated_delivery_date { "2011-09-16" }
sub new_nominated_selection_date { "2011-09-15" }

sub test_should_update_nominated_day : Tests {
    my ($self) = @_;

    my $invalid_new_nominated_delivery_date = "2011-09-11";
    my $same_valid_new_nominated_delivery_date = "2011-09-15"; # Same as the existing
    my $different_valid_new_nominated_delivery_date
        = $self->different_valid_new_nominated_delivery_date;

    my $setup_available_delivery_dates = $self->setup_available_delivery_dates;
    my $test_cases = [
        # Do update
        {
            description => "New date, all good",
            setup => {
                nominated_delivery_date     => $self->nominated_delivery_date,
                available_delivery_dates    => $setup_available_delivery_dates,
                shipment_item_status        => $SHIPMENT_ITEM_STATUS__NEW,
                new_nominated_delivery_date => $different_valid_new_nominated_delivery_date,
            },
            expected => {
                should_update => XT::Net::WebsiteAPI::Response::AvailableDate->new({
                    delivery_date => $different_valid_new_nominated_delivery_date,
                    # Test sets it up as the same. Normally this is the
                    # day before the delivery date.
                    dispatch_date => $different_valid_new_nominated_delivery_date,
                }),
            },
        },
        {
            description => "New Premier Shipping Charge, all good",
            setup => {
                nominated_delivery_date     => $self->nominated_delivery_date,
                available_delivery_dates    => $setup_available_delivery_dates,
                shipment_item_status        => $SHIPMENT_ITEM_STATUS__NEW,
                new_nominated_delivery_date => $same_valid_new_nominated_delivery_date,
                previous_shipping_charge    => $self->other_premier_shipping_charge,
            },
            expected => {
                should_update => XT::Net::WebsiteAPI::Response::AvailableDate->new({
                    delivery_date => $same_valid_new_nominated_delivery_date,
                    dispatch_date => $same_valid_new_nominated_delivery_date,
                }),
            },
        },
        # Don't update
        {
            description => "No New date",
            setup => {
                nominated_delivery_date     => $self->nominated_delivery_date,
                available_delivery_dates    => $setup_available_delivery_dates,
                shipment_item_status        => $SHIPMENT_ITEM_STATUS__NEW,
                new_nominated_delivery_date => undef,
            },
            expected => {
                should_update => 0,
            },
        },
        {
            description => "No Shipment date",
            setup => {
                nominated_delivery_date     => undef,
                available_delivery_dates    => $setup_available_delivery_dates,
                shipment_item_status        => $SHIPMENT_ITEM_STATUS__NEW,
                new_nominated_delivery_date => $different_valid_new_nominated_delivery_date,
            },
            expected => {
                should_update => XT::Net::WebsiteAPI::Response::AvailableDate->new({
                    delivery_date => $different_valid_new_nominated_delivery_date,
                    dispatch_date => $different_valid_new_nominated_delivery_date, # Same, see above
                }),
            },
        },
        {
            description => "Same date",
            setup => {
                nominated_delivery_date     => $self->nominated_delivery_date,
                available_delivery_dates    => $setup_available_delivery_dates,
                shipment_item_status        => $SHIPMENT_ITEM_STATUS__NEW,
                new_nominated_delivery_date => $same_valid_new_nominated_delivery_date,
            },
            expected => {
                should_update => 0,
            },
        },
        {
            description => "Is already selected",
            setup => {
                nominated_delivery_date     => $self->nominated_delivery_date,
                available_delivery_dates    => $setup_available_delivery_dates,
                shipment_item_status        => $SHIPMENT_ITEM_STATUS__PICKED,
                new_nominated_delivery_date => $different_valid_new_nominated_delivery_date,
            },
            expected => {
                throws => qr/Can't update the Shipment any longer, it's already selected for picking/,
            },
        },
        {
            description => "New Is not valid",
            setup => {
                nominated_delivery_date     => $self->nominated_delivery_date,
                available_delivery_dates    => $setup_available_delivery_dates,
                shipment_item_status        => $SHIPMENT_ITEM_STATUS__NEW,
                new_nominated_delivery_date => $invalid_new_nominated_delivery_date,
            },
            expected => {
                throws => qr/The new Nominated Delivery Date \($invalid_new_nominated_delivery_date\) is no longer valid/,
            },
        },
    ];
    note("*** Test Update Nominated Day");

    for my $case (@$test_cases) {
        subtest $case->{description} => sub {
            note 'Setup';
            my $setup = $case->{setup} || {};
            my $expected = $case->{expected};
            my ($shipment, $response_or_data) = Test::XTracker::Data::Order->create_shipment_and_response(
                $self->{channel},
                $setup,
                $self->premier_shipping_charge,
            );
            # make sure the Customer's Category is 'None'
            my $customer = $shipment->order->customer;
            $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );

            my $schema = $self->schema;
            my $id_shipment_item = get_shipment_item_info( $schema->storage->dbh, $shipment->id );
            my $shipment_address= get_address_info(
                $schema,
                $shipment->shipment_address_id,
            );

            my $previous_shipping_charge
                = $setup->{previous_shipping_charge} || $shipment->shipping_charge_table;

            note 'Run';
            my $should_update;
            my $e;
            XT::Net::WebsiteAPI::TestUserAgent->with_get_response(
                $response_or_data,
                sub {
                    eval {
                        $should_update = XTracker::Order::Actions::UpdateShipment::should_update_nominated_day(
                            $previous_shipping_charge->id,
                            $setup->{new_nominated_delivery_date},
                            $shipment,
                            $id_shipment_item,
                            $shipment_address,
                        );
                    };
                    $e = $@;
                },
            );

            if(my $throws = $expected->{throws}) {
                like( ($e || ""), $throws, "Throws the correct exception ($throws)");
                $e or fail("    No exception was thrown at all");
            }
            else {
                $e and fail("Expected normal exit, but an exception was thrown ($e)");
            }

            if(exists $expected->{should_update}) {
                eq_or_diff(
                    [ $should_update ],
                    [ $expected->{should_update} ],
                    "should_update_nominated_day returns $expected->{should_update}",
                );
            }
        };
    }
}

# Test the various input/output to get_shipping_options()
# The number of combinations for all of these is staggering, so only a
# few sanity checks are done
sub test_get_shipping_options : Tests {
    my ( $self ) = @_;

    my $test_cases = [
        {
            description => "Not Selected, domestic, no awb, no nom",
            setup => {
                shipment_item_status    => $SHIPMENT_ITEM_STATUS__NEW,
                shipment_status         => $SHIPMENT_STATUS__PROCESSING,
                outward_airway_bill     => "none",
                shipment_type           => $SHIPMENT_TYPE__DOMESTIC,
                nominated_delivery_date => undef,
            },
            expected => {
                selected                                    => 0,
                picked                                      => 0,
                packed                                      => 0,
                can_change_shipping_options                 => 1,
                can_change_shipping_charge_to_nominated_day => 1,
                can_change_nominated_day_delivery_date      => 0,
            },
        },
        {
            description => "Not Selected, domestic, no awb, nominated day",
            setup => {
                shipment_item_status    => $SHIPMENT_ITEM_STATUS__NEW,
                shipment_status         => $SHIPMENT_STATUS__PROCESSING,
                outward_airway_bill     => "none",
                shipment_type           => $SHIPMENT_TYPE__DOMESTIC,
                nominated_delivery_date => $self->nominated_delivery_date,
            },
            expected => {
                selected                                    => 0,
                picked                                      => 0,
                packed                                      => 0,
                can_change_shipping_options                 => 1,
                can_change_shipping_charge_to_nominated_day => 1,
                can_change_nominated_day_delivery_date      => 1,
            },
        },

        {
            description => "Selected, domestic, no awb, nominated day",
            setup => {
                shipment_item_status    => $SHIPMENT_ITEM_STATUS__SELECTED,
                shipment_status         => $SHIPMENT_STATUS__PROCESSING,
                outward_airway_bill     => "abc123",
                shipment_type           => $SHIPMENT_TYPE__DOMESTIC,
                nominated_delivery_date => $self->nominated_delivery_date,
            },
            expected => {
                selected                                    => 1,
                picked                                      => 0,
                packed                                      => 0,
                can_change_shipping_options                 => 0, # got awb
                can_change_shipping_charge_to_nominated_day => 0, # shiment_item is selected
                can_change_nominated_day_delivery_date      => 0, # got delivery date, but already selected
            },
        },

        {
            description => "Selected, domestic, no awb, nominated day",
            setup => {
                shipment_item_status    => $SHIPMENT_ITEM_STATUS__SELECTED,
                shipment_status         => $SHIPMENT_STATUS__PROCESSING,
                outward_airway_bill     => "none",
                shipment_type           => $SHIPMENT_TYPE__DOMESTIC,
                nominated_delivery_date => $self->nominated_delivery_date,
            },
            expected => {
                selected                                    => 1,
                picked                                      => 0,
                packed                                      => 0,
                can_change_shipping_options                 => 1, # no awb
                can_change_shipping_charge_to_nominated_day => 0, # shiment_item is selected
                can_change_nominated_day_delivery_date      => 0, # got delivery date, but already selected
            },
        },

        {
            description => "Selected, domestic, no awb, nominated day",
            setup => {
                shipment_item_status    => $SHIPMENT_ITEM_STATUS__SELECTED,
                shipment_status         => $SHIPMENT_STATUS__PROCESSING,
                outward_airway_bill     => "whatever", # Could well be "none", for Premier shipments
                shipment_type           => $SHIPMENT_TYPE__PREMIER,
                nominated_delivery_date => $self->nominated_delivery_date,
            },
            expected => {
                selected                                    => 1,
                picked                                      => 0,
                packed                                      => 0,
                can_change_shipping_options                 => 1, # premier
                can_change_shipping_charge_to_nominated_day => 0, # shiment_item is selected
                can_change_nominated_day_delivery_date      => 0, # got delivery date, but already selected
            },
        },
    ];
    note("*** Test get_shipping_options");

    for my $case (@$test_cases) {
        subtest $case->{description} => sub {
            note 'Setup';
            my $setup = $case->{setup} || {};
            my $expected = $case->{expected};
            my ($shipment_row, $response_or_data) = Test::XTracker::Data::Order->create_shipment_and_response(
                $self->{channel},
                $setup,
                $self->premier_shipping_charge,
            );
            # make sure the Customer's Category is 'None'
            my $customer = $shipment_row->order->customer;
            $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );

            note("order_id(" . $shipment_row->order->id . "), shipment_id(" . $shipment_row->id . ")");
            $shipment_row->update({
                outward_airway_bill     => $setup->{outward_airway_bill},
            });

            my $dbh = $self->schema->storage->dbh;
            my $shipment = get_shipment_info( $dbh, $shipment_row->id );
            my $id_shipment_item = get_shipment_item_info( $dbh, $shipment_row->id );

            my $shipping_option = XTracker::Order::Functions::Shipment::EditShipment::get_shipping_options(
                $shipment,
                $id_shipment_item,
            );

            for my $key (keys %$expected) {
                is(
                    $shipping_option->{$key} || 0,
                    $expected->{$key},
                    "$key is ok ($expected->{$key})",
                );
            }
        };
    }
}

# Test that the combination of current nominated available days and
# other Nominated Day skus are returned by
# get_sku_current_and_available_nominated_delivery_dates
#
# Note: The test setup for this is pretty complicated.
sub current_premier_shipping_charge {
    my $self = shift;
    my $current_premier_sku = {
        DC1 => "9000210-001",
        DC2 => "9000211-001",
        DC3 => "9000324-001",
    }->{$distribution_centre} or die("Unknown DC ($distribution_centre)");
    return $self->schema->resultset(
        "Public::ShippingCharge",
    )->search({ sku => "$current_premier_sku"})->first || die("Unknown SKU ($current_premier_sku)");
}

sub test_get_sku_current_and_available_nominated_delivery_dates : Tests {
    my ($self) = @_;

    # The dates that would be returned from the Website API
    my $standar_dates = [ $self->different_valid_new_nominated_delivery_date ];
    my $standar_dates_response = create_available_dates_deserialised_response(
        $standar_dates,
    );
    my $nominated_delivery_date_response = create_available_dates_deserialised_response(
        [ $self->nominated_delivery_date ],
    );

    my $test_cases = [
        {
            prefix      => "!Nom, !Dates",
            description => "Current no nom => no available dates from API",
            setup => {
                nominated_delivery_date          => undef,
                shipping_charge_id               => $self->premier_shipping_charge->id,
                available_delivery_dates         => [],
                current_available_delivery_dates => [],
            },
            expected => {
                dc_sku_available_days => {
                    # The Nominated day SKUs for the current_dc_premier address
                    DC1 => { "9000210-001" => [], "9000222-001" => [], },
                    DC2 => { "9000211-001" => [], "9000217-001" => [], },
                    DC3 => { "9000324-001" => [], "9000323-001" => [], },
                },
            },
        },
        {
            prefix      => "!Nom, Dates",
            description => "Current no nom => all nom skus, normal dates from API",
            setup => {
                nominated_delivery_date          => undef,
                shipping_charge_id               => $self->non_premier_shipping_charge->id,
                available_delivery_dates         => $standar_dates,
                current_available_delivery_dates => [ ],
            },
            expected => {
                dc_sku_available_days => {
                    # The Nominated day SKUs for the current_dc_premier address
                    DC1 => {
                        "9000210-001" => $standar_dates_response,
                        "9000222-001" => $standar_dates_response,
                    },
                    DC2 => {
                        "9000211-001" => $standar_dates_response,
                        "9000217-001" => $standar_dates_response,
                    },
                    DC3 => {
                        "9000324-001" => $standar_dates_response,
                        "9000323-001" => $standar_dates_response,
                    },
                },
            },
        },
        {
            prefix      => "Nom, No Dates",
            description => "Current nom, no available dates from API, only includes the current date for the current sku",
            setup => {
                nominated_delivery_date          => $self->nominated_delivery_date,
                shipping_charge_id               => $self->current_premier_shipping_charge->id,
                available_delivery_dates         => [ ],
                current_available_delivery_dates => [ $self->nominated_delivery_date ],
            },
            expected => {
                dc_sku_available_days => {
                    # The Nominated day SKUs for the current_dc_premier address
                    DC1 => {
                        "9000210-001" => $nominated_delivery_date_response,
                        "9000222-001" => [ ],
                    },
                    DC2 => {
                        "9000211-001" => $nominated_delivery_date_response,
                        "9000217-001" => [ ],
                    },
                    DC3 => {
                        "9000324-001" => $nominated_delivery_date_response,
                        "9000323-001" => [ ],
                    },
                },
            },
        },
        {
            prefix      => "Nom, Dates",
            description => "Current nom => all nom skus, normal dates, current sku includes current delivery date",
            setup => {
                nominated_delivery_date          => $self->nominated_delivery_date,
                shipping_charge_id               => $self->current_premier_shipping_charge->id,
                available_delivery_dates         => $standar_dates,
                current_available_delivery_dates => [ $self->nominated_delivery_date ],
            },
            expected => {
                dc_sku_available_days => {
                    # The Nominated day SKUs for the current_dc_premier address
                    DC1 => {
                        "9000210-001" => $nominated_delivery_date_response,
                        "9000222-001" => $standar_dates_response,
                    },
                    DC2 => {
                        "9000211-001" => $nominated_delivery_date_response,
                        "9000217-001" => $standar_dates_response,
                    },
                    DC3 => {
                        "9000324-001" => $nominated_delivery_date_response,
                        "9000323-001" => $standar_dates_response,
                    },
                },
            },
        },
    ];

    note("*** Test get_sku_current_and_available_nominated_delivery_dates");

    for my $case (@$test_cases) {
        subtest $case->{description} => sub {
            note 'Setup';
            my $setup = $case->{setup} || {};
            my $expected = $case->{expected};
            my ($shipment_row, $response_or_data) = Test::XTracker::Data::Order->create_shipment_and_response(
                $self->{channel},
                $setup,
                $self->premier_shipping_charge,
            );
            # make sure the Customer's Category is 'None'
            my $customer = $shipment_row->order->customer;
            $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );

            my $schema = $self->schema;
            my $shipment_address = get_address_info(
                $schema,
                $shipment_row->shipment_address_id,
            );
            my %shipping_charges = get_address_shipping_charges(
                $schema->storage->dbh,
                $self->{channel}->id,
                {
                    country  => $shipment_address->{country},
                    postcode => $shipment_address->{postcode},
                    state    => $shipment_address->{county},
                },
                {
                    exclude_nominated_day   => 0,
                }
            );

            note 'Run';
            my $current_available_dates = create_available_dates_deserialised_response(
                $setup->{current_available_delivery_dates},
            );
            my $sku_available_dates = XT::Net::WebsiteAPI::TestUserAgent->with_get_response(
                $response_or_data,
                sub {
                    XTracker::Order::Functions::Shipment::EditShipment::get_sku_current_and_available_nominated_delivery_dates(
                        $self->{channel},
                        \%shipping_charges,
                        $shipment_address,
                        $shipment_row->shipping_charge_table->sku,
                        $current_available_dates,
                    );
                },
                1, # Keep response
            );
            my $sku_available_dates_json = XTracker::Order::Functions::Shipment::EditShipment::json_from_sku_available_dates(
                $sku_available_dates,
            );

            eq_or_diff(
                $sku_available_dates,
                $expected->{dc_sku_available_days}->{$distribution_centre},
                "Expected skus ok",
            );

            # Check that the number of times a date is present in the JSON
            # is the same as in the data structure
            my @dates = map { $_->delivery_date, $_->dispatch_date } map { @$_ } values %$sku_available_dates;
            my %date_count;
            $date_count{$_}++ for @dates;
            for my $date (sort keys %date_count) {
                my $json_count = () = $sku_available_dates_json =~ /($date)/g;
                is(
                    $json_count,
                    $date_count{$date},
                    "The date ($date) occurs the same number of times in the JSON",
                );
            }
        };
    }
}

sub test_update_nominated_day : Tests {
    my ($self) = @_;

    # Test one ok to see that it updates ok, and one failing to see the error message
    my $nominated_delivery_web_date = Test::XTracker::Data::Shipping->to_uk_web_date_format(
        $self->nominated_delivery_date,
    );
    my $different_valid_new_nominated_delivery_date
        = $self->different_valid_new_nominated_delivery_date;
    my $different_valid_new_nominated_delivery_web_date = Test::XTracker::Data::Shipping->to_uk_web_date_format(
        $different_valid_new_nominated_delivery_date,
    );

    my $setup_available_delivery_dates = $self->setup_available_delivery_dates;
    my $test_cases = [
        {
            description => "New date, changes the data",
            setup => {
                nominated_delivery_date     => $self->nominated_delivery_date,
                available_delivery_dates    => $setup_available_delivery_dates,
                shipment_item_status        => $SHIPMENT_ITEM_STATUS__NEW,
                new_nominated_delivery_date => $different_valid_new_nominated_delivery_date,
            },
            expected => {
                delivery_date    => $different_valid_new_nominated_delivery_date,
                # Test sets it up on the same date. Normally this is the
                # day before the delivery date.
                dispatch_date    => $different_valid_new_nominated_delivery_date,
                selection_date   => $self->new_nominated_selection_date,
                shipment_note_qr => qr/\QNominated Delivery Date($nominated_delivery_web_date => $different_valid_new_nominated_delivery_web_date)/,
            },
        },

        {
            description => "Is already selected, gives correct error message",
            setup => {
                nominated_delivery_date     => $self->nominated_delivery_date,
                available_delivery_dates    => $setup_available_delivery_dates,
                shipment_item_status        => $SHIPMENT_ITEM_STATUS__NEW,
                new_nominated_delivery_date => $different_valid_new_nominated_delivery_date,
                website_response_2          => HTTP::Response->new(404 => "Not found"),
            },
            expected => {
                error_message => qr/Couldn't determine available delivery days, please retry later if you need to change it. Please contact ServiceDesk if this persists, or is urgent./,
            },
        },
    ];

    note("*** Test Update Nominated Day (integration test with Flow methods)");

    for my $case (@$test_cases) {
        subtest $case->{description} => sub {
            my $setup = $case->{setup} || {};
            my $expected = $case->{expected};
            my ($shipment, $response_or_data) = Test::XTracker::Data::Order->create_shipment_and_response(
                $self->{channel},
                $setup,
                $self->premier_shipping_charge,
            );
            # make sure the Customer's Category is 'None'
            my $customer = $shipment->order->customer;
            $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );

            my $framework = $self->{framework};
            my $mech = $framework->mech;
            XT::Net::WebsiteAPI::TestUserAgent->with_get_response(
                $response_or_data,
                sub { $framework->flow_mech__customercare__edit_shipment($shipment) },
            );

            $response_or_data = $setup->{website_response_2} if($setup->{website_response_2});
            XT::Net::WebsiteAPI::TestUserAgent->with_get_response(
                $response_or_data,
                sub {
                    $mech->form_name("editShipment");
                    $mech->select(
                        nominated_delivery_date => $setup->{new_nominated_delivery_date},
                    );
                    $mech->submit();
                },
            );

            note("Test Web page");
            like(
                $mech->uri . "",
                qr|/CustomerCare/OrderSearch/OrderView|,
                "Ended up on the correct resulting URI",
            );

            if(my $error_message = $expected->{error_message}) {
                like(
                    $mech->content,
                    qr/$error_message/sm,
                    "  and the correct error message is present",
                );

                return; # Error message ==> nothing more to test here
            }


            $framework->flow_mech__customercare__orderview($shipment->order->id);
            my $shipment_details = $mech->as_data->{meta_data}{"Shipment Details"};
            is(
                $shipment_details->{"Nominated Delivery Date"},
                to_web_date_format($expected->{delivery_date}),
                "Delivery Date ok",
            );

            note("Test DB");
            $shipment->discard_changes();
            is(
                $shipment->nominated_delivery_date->ymd,
                $expected->{delivery_date},
                "delivery_date ok",
            );
            is(
                $shipment->nominated_dispatch_time->ymd,
                $expected->{dispatch_date},
                "dispatch_time ok",
            );
            is(
                $shipment->nominated_earliest_selection_time->ymd,
                $expected->{selection_date},
                "selection_time ok",
            );
            SKIP: {
                my $day_plus_2h = DateTime->now->add(hours => 2)
                    ->truncate(to => "day")->ymd;
                my $day = DateTime->now
                    ->truncate(to => "day")->ymd;

                note("Checking day ($day) vs day + 2h ($day_plus_2h)");
                if( $day_plus_2h ne $day ) {
                    skip(
                        "Skip the date comparison assertion if it will fail because the test is run too close to midnight",
                        1,
                    );
                }

                TODO: {
                    local $TODO = "WHM-2770: This test fails for the last two hours of every day";

                    my $sla_cutoff = $shipment->sla_cutoff;
                    # XXX: should today_2h_from_now really be in the TZ of the DC?
                    my $today_2h_from_now = DateTime->now->add(hours => 2);
                    is(
                        $sla_cutoff->ymd,
                        $today_2h_from_now->clone->truncate(to => "day")->ymd,
                        "sla_cutoff ok (earliest sla_cutoff is two hours(?) from now)",
                    ) or diag("Compared sla_cutoff ($sla_cutoff " . $sla_cutoff->time_zone_short_name . ") and 2h from now ($today_2h_from_now " . $today_2h_from_now->time_zone_short_name . ")");
                }
            }

            Test::XTracker::Data::Shipping->test_shipment_note($shipment, $expected);
        };
    }
}

sub create_available_dates_deserialised_response {
    my ($available_delivery_dates) = @_;

    my $available_delivery_dates_response = [
        map { as_full_available_date($_) }
        @$available_delivery_dates
    ];

    return $available_delivery_dates_response;
}

sub test_available_dates_args : Tests {
    my $self = shift;
    note "*** Test available_dates_args";

    my $schema = $self->schema;
    my $default_args = {
        sku      => "ABC",
        country  => "United Kingdom",
        postcode => "W6",
    };
    eq_or_diff(
        XTracker::Order::Functions::Shipment::EditShipment::available_dates_args(
            $schema,
            { %$default_args, county => "The Shire" },
        ),
        { %$default_args, state => undef, country => "GB" },
        "Not US",
    );

    eq_or_diff(
        XTracker::Order::Functions::Shipment::EditShipment::available_dates_args(
            $schema,
            { %$default_args, country => "United States", county => "NY" },
        ),
        { %$default_args, state => "NY", country => "US" },
        "US",
    );
}

sub test_get_all_available_nominated_delivery_dates : Tests {
    note "*** Test ensure_current_nominated_delivery_date_is_present";

    my $now = DateTime->now();

    note "Add to empty list";
    my $all_dates = XTracker::Order::Functions::Shipment::EditShipment::ensure_current_nominated_delivery_date_is_present(
        [],
        $now,
    );
    eq_or_diff(
        [ map { $_->delivery_date->ymd } @$all_dates ],
        [ $now->ymd ],
        "Added the nominated_delivery_date to empty list",
    );

    note "Add to existing list, in correct order";
    my $yesterday = $now->clone->subtract(days => 1);
    my $tomorrow = $now->clone->add(days => 1);
    $all_dates = XTracker::Order::Functions::Shipment::EditShipment::ensure_current_nominated_delivery_date_is_present(
        [ map { as_available_date($_) } ( $tomorrow, $yesterday ) ],
        $now,
    );
    for my $date (map { $_->delivery_date } @$all_dates) {
        isa_ok($date, "XT::Data::DateStamp", "available dates are correct type");
    }
    eq_or_diff(
        [ map { $_->delivery_date->ymd } @$all_dates ],
        [ map { $_->ymd } ( $yesterday, $now, $tomorrow ) ],
        "Added the nominated_delivery_date in the correct order to existing list",
    );

    note "Add to existing list with date already in it, in correct order";
    $all_dates = XTracker::Order::Functions::Shipment::EditShipment::ensure_current_nominated_delivery_date_is_present(
        [ map { as_available_date($_) } ( $tomorrow, $yesterday, $now ) ],
        $now,
    );
    eq_or_diff(
        [ map { $_->delivery_date->ymd } @$all_dates ],
        [ map { $_->ymd } ( $yesterday, $now, $tomorrow ) ],
        "Added the nominated_delivery_date in the correct order to existing list with date in it",
    );
}

# Check changing to and from Non-nominated-day, Nominated day,
# Premier, non-Premier

# Standard means: A shipping charge without Nominated Day

# Note: If you change shipping charges (especially delete them), you
# probably need to keep this table up to date
sub shipping_charge_config {
    return {
        DC1 => {
            dc_domestic_shipping_charge_sku => "900003-001", # UK Express
            dc_premier_shipping_charge_sku  => "9000210-001", # Premier Daytime - Zone 2
            dc_premier_shipping_charge_sku2 => "9000222-001", # Premier  - Zone 2
            domestic_shipping_charge_sku    => "900003-001", # UK Express
            domestic_shipping_charge_sku2   => "",           # Same everywhere in the UK, no "to"
        },
        DC2 => {
            dc_domestic_shipping_charge_sku => "900032-001", # New York Next Business Day
            dc_premier_shipping_charge_sku  => "9000211-001", # Premier Daytime
            dc_premier_shipping_charge_sku2 => "9000217-001", # Premier Evening
            domestic_shipping_charge_sku    => "900064-001", # Kentucky Next Business Day
            domestic_shipping_charge_sku2   => "900065-002", # Kentucky 3-5 Business Days
        },
        DC3 => {
            dc_domestic_shipping_charge_sku => "9000311-001", # Standard 2 Days Hong Kong
            dc_premier_shipping_charge_sku  => "9000324-001", # Premier Daytime
            dc_premier_shipping_charge_sku2 => "9000323-001", # Premier Evening
            domestic_shipping_charge_sku    => "9000311-001", # Standard 2 Days Honk Kong
            domestic_shipping_charge_sku2   => "",           # Same everywhere, no "to"
        },
    }->{$distribution_centre} || die("Unknown DC ($distribution_centre)");
}


sub test_update_shipping_charge_nominated_day : Tests {
    my ($self) = @_;

    my $nominated_selection_date = "2011-09-14";

    my $different_valid_new_nominated_delivery_date
        = $self->different_valid_new_nominated_delivery_date;
    my $shipping_charge_config = $self->shipping_charge_config;
    my $setup_available_delivery_dates = $self->setup_available_delivery_dates;
    my $test_cases = [
        {
            description => "Standard => Standard, no nom, normal sla",
            setup => {
                from => {
                    address_in              => "current_dc",
                    nominated_delivery_date => undef,
                    shipment_type           => $SHIPMENT_TYPE__DOMESTIC,
                    shipping_charge_sku     => $shipping_charge_config->{domestic_shipping_charge_sku},
                    shipment_item_status    => $SHIPMENT_ITEM_STATUS__NEW,
                },
                to => {
                    shipping_charge_sku     => $shipping_charge_config->{domestic_shipping_charge_sku2},
                    nominated_delivery_date => "",
                },
            },
            expected => {
                delivery_date        => undef,
                dispatch_date        => undef,
                selection_date       => undef,
                shipment_note_qr     => qr/^Shipping Charge\(.+? => .+?\), Shipping SKU\($shipping_charge_config->{domestic_shipping_charge_sku} => $shipping_charge_config->{domestic_shipping_charge_sku2}\)$/,
                premier_routing_code => "C", # The default non-premier_routing code
            },
        },
        {
            description => "Non-Premier => Premier, premier_routing is set",
            setup => {
                from => {
                    address_in              => "current_dc_premier",
                    nominated_delivery_date => undef,
                    shipment_type           => $SHIPMENT_TYPE__DOMESTIC,
                    shipping_charge_sku     => $shipping_charge_config->{dc_domestic_shipping_charge_sku},
                    shipment_item_status    => $SHIPMENT_ITEM_STATUS__NEW,
                    available_delivery_dates => $setup_available_delivery_dates,
                },
                to => {
                    shipping_charge_sku     => $shipping_charge_config->{dc_premier_shipping_charge_sku},
                    nominated_delivery_date => $different_valid_new_nominated_delivery_date,
                },
            },
            expected => {
                shipment_note_qr     => qr|^Nominated Delivery Date\( => [\d/]+\), Shipment Type\(.+? => .+?\), Shipping Charge\(.+? => .+?\), Shipping SKU\($shipping_charge_config->{dc_domestic_shipping_charge_sku} => $shipping_charge_config->{dc_premier_shipping_charge_sku}\)$|,
                premier_routing_code => "D",
            },
        },
        {
            description => "Premier => different Premier, premier_routing is changed",
            setup => {
                from => {
                    address_in              => "current_dc_premier",
                    nominated_delivery_date => undef,
                    shipment_type           => $SHIPMENT_TYPE__PREMIER,
                    shipping_charge_sku     => $shipping_charge_config->{dc_premier_shipping_charge_sku},
                    nominated_delivery_date => $different_valid_new_nominated_delivery_date,
                    shipment_item_status    => $SHIPMENT_ITEM_STATUS__NEW,
                    available_delivery_dates => $setup_available_delivery_dates,
                },
                to => {
                    shipping_charge_sku     => $shipping_charge_config->{dc_premier_shipping_charge_sku2},
                },
            },
            expected => {
                shipment_note_qr     => qr/^Shipping Charge\(.+? => .+?\), Shipping SKU\($shipping_charge_config->{dc_premier_shipping_charge_sku} => $shipping_charge_config->{dc_premier_shipping_charge_sku2}\)$/,
                premier_routing_code => "E",
            },
        },
        {
            description => "Standard => Nominated Day, sets all ND attributes, and sla",
            setup => {
                from => {
                    address_in               => "current_dc_premier",
                    nominated_delivery_date  => undef,
                    shipment_type            => $SHIPMENT_TYPE__DOMESTIC,
                    shipping_charge_sku      => $shipping_charge_config->{dc_domestic_shipping_charge_sku},
                    shipment_item_status     => $SHIPMENT_ITEM_STATUS__NEW,
                    available_delivery_dates => $setup_available_delivery_dates,
                },
                to => {
                    shipping_charge_sku     => $shipping_charge_config->{dc_premier_shipping_charge_sku},
                    nominated_delivery_date => $different_valid_new_nominated_delivery_date,
                },
            },
            expected => {
                delivery_date        => $different_valid_new_nominated_delivery_date,
                dispatch_date        => $different_valid_new_nominated_delivery_date, # Premier, so dispatched on the same day
                selection_date       => $self->new_nominated_selection_date,
                shipment_note_qr     => qr|^Nominated Delivery Date\( => [/\d]+\), Shipment Type\(Domestic => Premier\), Shipping Charge\(.+? => .+?\), Shipping SKU\($shipping_charge_config->{dc_domestic_shipping_charge_sku} => $shipping_charge_config->{dc_premier_shipping_charge_sku}\)$|,
                premier_routing_code => "D",
            },
        },
        {
            description => "Standard => Nominated Day, sets all ND attributes, and sla",
            setup => {
                from => {
                    address_in               => "current_dc_premier",
                    shipment_type            => $SHIPMENT_TYPE__PREMIER,
                    shipping_charge_sku      => $shipping_charge_config->{dc_premier_shipping_charge_sku},
                    shipment_item_status     => $SHIPMENT_ITEM_STATUS__NEW,
                    available_delivery_dates => $setup_available_delivery_dates,
                    nominated_delivery_date  => $different_valid_new_nominated_delivery_date,
                },
                to => {
                    shipping_charge_sku     => $shipping_charge_config->{dc_domestic_shipping_charge_sku},
                    nominated_delivery_date => "",
                },
            },
            expected => {
                delivery_date        => undef,
                dispatch_date        => undef,
                selection_date       => undef,
                shipment_note_qr     => qr|^Nominated Delivery Date\([/\d]+ => \), Shipment Type\(Premier => Domestic\), Shipping Charge\(.+? => .+?\), Shipping SKU\($shipping_charge_config->{dc_premier_shipping_charge_sku} => $shipping_charge_config->{dc_domestic_shipping_charge_sku}\)$|,
                premier_routing_code => "C",
            },
        },
        {
            description => "Nominated Day => different Nominated Day, sets all ND attributes, and sla, changes dates",
            setup => {
                from => {
                    address_in               => "current_dc_premier",
                    shipment_type            => $SHIPMENT_TYPE__PREMIER,
                    shipping_charge_sku      => $shipping_charge_config->{dc_premier_shipping_charge_sku},
                    shipment_item_status     => $SHIPMENT_ITEM_STATUS__NEW,
                    available_delivery_dates => $setup_available_delivery_dates,
                    nominated_delivery_date  => $self->nominated_delivery_date,
                },
                to => {
                    shipping_charge_sku     => $shipping_charge_config->{dc_premier_shipping_charge_sku2},
                    nominated_delivery_date => $different_valid_new_nominated_delivery_date,
                },
            },
            expected => {
                delivery_date        => $different_valid_new_nominated_delivery_date,
                dispatch_date        => $different_valid_new_nominated_delivery_date,
                selection_date       => $self->new_nominated_selection_date,
                shipment_note_qr     => qr|^Nominated Delivery Date\([/\d]+ => [/\d]+\), Shipping Charge\(.+? => .+?\), Shipping SKU\($shipping_charge_config->{dc_premier_shipping_charge_sku} => $shipping_charge_config->{dc_premier_shipping_charge_sku2}\)$|,
                premier_routing_code => "E",
            },
        },
        {
            description => "Nominated Day => different Shipping Charge, same date, sets all ND attributes, and sla, changes dates",
            setup => {
                from => {
                    address_in               => "current_dc_premier",
                    shipment_type            => $SHIPMENT_TYPE__PREMIER,
                    shipping_charge_sku      => $shipping_charge_config->{dc_premier_shipping_charge_sku},
                    shipment_item_status     => $SHIPMENT_ITEM_STATUS__NEW,
                    available_delivery_dates => $setup_available_delivery_dates,
                    nominated_delivery_date  => $self->nominated_delivery_date,
                },
                to => {
                    shipping_charge_sku     => $shipping_charge_config->{dc_premier_shipping_charge_sku2},
                    nominated_delivery_date => $self->nominated_delivery_date,
                },
            },
            expected => {
                delivery_date        => $self->nominated_delivery_date,
                dispatch_date        => $self->nominated_delivery_date,
                selection_date       => $nominated_selection_date,
                shipment_note_qr     => qr|^Shipping Charge\(.+? => .+?\), Shipping SKU\($shipping_charge_config->{dc_premier_shipping_charge_sku} => $shipping_charge_config->{dc_premier_shipping_charge_sku2}\)$|,
                premier_routing_code => "E",
            },
        },
    ];

    note("*** Test Update Shipping Option and/or Nominated Day (integration test with Flow methods)");

    for my $case (@$test_cases) {
        subtest $case->{description} => sub {
            note 'Setup';
            my $setup    = $case->{setup} || {};
            my $expected = $case->{expected};

            my $to_shipping_charge_id
                = $self->id_from_sku($setup->{to}->{shipping_charge_sku})
                || plan skip_all => <<EOS
SKIPPING the case ($case->{description}):
    Need a 'to' shipping charge for this test case.
    (this might well be normal data for a DC)
EOS
            ;

            my ($shipment, $response_or_data) = Test::XTracker::Data::Order->create_shipment_and_response(
                $self->{channel},
                {
                    %{$setup->{from}},
                    shipping_charge_id => $self->id_from_sku($setup->{from}->{shipping_charge_sku}),
                },
                $self->premier_shipping_charge,
            );
            # make sure the Customer's Category is 'None'
            my $customer = $shipment->order->customer;
            $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );

            note 'Run';

            my $framework = $self->{framework};
            my $mech = $framework->mech;
            XT::Net::WebsiteAPI::TestUserAgent->with_get_response(
                $response_or_data,
                sub { $framework->flow_mech__customercare__edit_shipment($shipment) },
            );

            $mech->form_name("editShipment");
            $mech->select(shipping_charge_id => $to_shipping_charge_id);
            if(my $nominated_delivery_date = $setup->{to}->{nominated_delivery_date}) {

                # Here we have to insist the value exists since $mech
                # might not know about it (sometimes it's not rendered,
                # sometimes it's replaced client side)
                $mech->current_form->force_field(
                    nominated_delivery_date => $nominated_delivery_date,
                );
            }

            XT::Net::WebsiteAPI::TestUserAgent->with_get_response(
                $response_or_data,
                sub { $mech->submit() },
            );

            note("Test Web page");
            like(
                $mech->uri . "",
                qr|/CustomerCare/OrderSearch/OrderView|,
                "Ended up on the correct resulting URI",
            );
            if(my $error_message = $expected->{error_message}) {
                like(
                    $mech->content,
                    qr/$error_message/sm,
                    "  and the correct error message is present",
                );

                return; # Error message ==> nothing more to test here
            }
            else {
                if($mech->content =~ m{<p class="error_msg".*?>\s*(.+?)\s*</p>}) {
                    my $error = $1;
                    fail("Didn't expect any error messages, but encountered one anyway:\nERROR($error)\n");
                    return; # Unexpected Error message ==> no point in testing anything else
                }
            }

            note("Test DB");
            my $old_sla_cutoff = $shipment->sla_cutoff;
            $shipment->discard_changes();

            my $test_attributes = {
                nominated_delivery_date  => "delivery_date",
                nominated_dispatch_time  => "dispatch_date",
                nominated_earliest_selection_time => "selection_date",
            };
            for my $column (keys %{$test_attributes}) {
                my $attribute = $test_attributes->{$column};
                note("Testing col ($column), attr ($attribute)");
                my $column_value = undef;
                exists $expected->{$attribute} and $column_value = ymd($shipment->$column);
                is($column_value, $expected->{$attribute}, "    $attribute ok");
            }
            is(
                $shipment->premier_routing->code,
                $expected->{premier_routing_code},
                "premier_routing_code ok",
            );

            Test::XTracker::Data::Shipping->test_shipment_note($shipment, $expected);
        };
    }
}

sub test_update_shipping_charge_eip_customer : Tests {
    my ($self) = @_;

    my $different_valid_new_nominated_delivery_date
        = $self->different_valid_new_nominated_delivery_date;
    my $shipping_charge_config = $self->shipping_charge_config;
    my $setup_available_delivery_dates = $self->setup_available_delivery_dates;
    my $test_cases = [
        {
            description => "Non-Premier => Premier, Shipping Charge Changes, Customer Category: None",
            setup => {
                from => {
                    customer_category       => $CUSTOMER_CATEGORY__NONE,
                    address_in              => "current_dc_premier",
                    nominated_delivery_date => undef,
                    shipment_type           => $SHIPMENT_TYPE__DOMESTIC,
                    shipping_charge_sku     => $shipping_charge_config->{dc_domestic_shipping_charge_sku},
                    shipment_item_status    => $SHIPMENT_ITEM_STATUS__NEW,
                    available_delivery_dates => $setup_available_delivery_dates,
                },
                to => {
                    shipping_charge_sku     => $shipping_charge_config->{dc_premier_shipping_charge_sku},
                    nominated_delivery_date => $different_valid_new_nominated_delivery_date,
                },
            },
            expected => {
                change_in_shipping_charge => 1,
                premier_routing_code      => "D",
            },
        },
        {
            description => "Non-Premier => Premier, Shipping Charge DOESN'T Change, Customer Category: EIP Premium",
            setup => {
                from => {
                    customer_category       => $CUSTOMER_CATEGORY__EIP_PREMIUM,
                    address_in              => "current_dc_premier",
                    nominated_delivery_date => undef,
                    shipment_type           => $SHIPMENT_TYPE__DOMESTIC,
                    shipping_charge_sku     => $shipping_charge_config->{dc_domestic_shipping_charge_sku},
                    shipment_item_status    => $SHIPMENT_ITEM_STATUS__NEW,
                    available_delivery_dates => $setup_available_delivery_dates,
                },
                to => {
                    shipping_charge_sku     => $shipping_charge_config->{dc_premier_shipping_charge_sku},
                    nominated_delivery_date => $different_valid_new_nominated_delivery_date,
                },
            },
            expected => {
                change_in_shipping_charge => 0,
                premier_routing_code      => "D",
            },
        },
        {
            description => "Premier => Non-Premier, Shipping Charge Changes, Customer Category: None",
            setup => {
                from => {
                    customer_category       => $CUSTOMER_CATEGORY__NONE,
                    address_in              => "current_dc_premier",
                    nominated_delivery_date => undef,
                    shipment_type           => $SHIPMENT_TYPE__PREMIER,
                    shipping_charge_sku     => $shipping_charge_config->{dc_premier_shipping_charge_sku},
                    shipment_item_status    => $SHIPMENT_ITEM_STATUS__NEW,
                    available_delivery_dates => $setup_available_delivery_dates,
                },
                to => {
                    shipping_charge_sku     => $shipping_charge_config->{dc_domestic_shipping_charge_sku},
                    nominated_delivery_date => $different_valid_new_nominated_delivery_date,
                },
            },
            expected => {
                change_in_shipping_charge => 1,
                premier_routing_code      => "C",
            },
        },
        {
            description => "Premier => Non-Premier, Shipping Charge DOESN'T Chnage, Customer Category: EIP Premium",
            setup => {
                from => {
                    customer_category       => $CUSTOMER_CATEGORY__EIP_PREMIUM,
                    address_in              => "current_dc_premier",
                    nominated_delivery_date => undef,
                    shipment_type           => $SHIPMENT_TYPE__PREMIER,
                    shipping_charge_sku     => $shipping_charge_config->{dc_premier_shipping_charge_sku},
                    shipment_item_status    => $SHIPMENT_ITEM_STATUS__NEW,
                    available_delivery_dates => $setup_available_delivery_dates,
                },
                to => {
                    shipping_charge_sku     => $shipping_charge_config->{dc_domestic_shipping_charge_sku},
                    nominated_delivery_date => $different_valid_new_nominated_delivery_date,
                },
            },
            expected => {
                change_in_shipping_charge => 0,
                premier_routing_code      => "C",
            },
        },
        {
            description => "Nominated Day => different Shipping Charge, Shipping Charge Changes, Customer Category: None",
            setup => {
                from => {
                    customer_category        => $CUSTOMER_CATEGORY__NONE,
                    address_in               => "current_dc_premier",
                    shipment_type            => $SHIPMENT_TYPE__PREMIER,
                    shipping_charge_sku      => $shipping_charge_config->{dc_premier_shipping_charge_sku},
                    shipment_item_status     => $SHIPMENT_ITEM_STATUS__NEW,
                    available_delivery_dates => $setup_available_delivery_dates,
                    nominated_delivery_date  => $self->nominated_delivery_date,
                },
                to => {
                    shipping_charge_sku     => $shipping_charge_config->{dc_premier_shipping_charge_sku2},
                    nominated_delivery_date => $self->nominated_delivery_date,
                },
            },
            expected => {
                change_in_shipping_charge => 1,
                premier_routing_code      => "E",
            },
        },
        {
            description => "Nominated Day => different Shipping Charge, Shipping Charge DOESN'T Change, Customer Category: EIP",
            setup => {
                from => {
                    customer_category        => $CUSTOMER_CATEGORY__EIP,
                    address_in               => "current_dc_premier",
                    shipment_type            => $SHIPMENT_TYPE__PREMIER,
                    shipping_charge_sku      => $shipping_charge_config->{dc_premier_shipping_charge_sku},
                    shipment_item_status     => $SHIPMENT_ITEM_STATUS__NEW,
                    available_delivery_dates => $setup_available_delivery_dates,
                    nominated_delivery_date  => $self->nominated_delivery_date,
                },
                to => {
                    shipping_charge_sku     => $shipping_charge_config->{dc_premier_shipping_charge_sku2},
                    nominated_delivery_date => $self->nominated_delivery_date,
                },
            },
            expected => {
                change_in_shipping_charge => 0,
                premier_routing_code      => "E",
            },
        },
    ];

    note("*** Test Update Shipping Option for EIP Customers (integration test with Flow methods)");

    for my $case ( @$test_cases ) {
        subtest $case->{description} => sub {
            note 'Setup';
            my $setup    = $case->{setup} || {};
            my $expected = $case->{expected};

            my $to_shipping_charge_id
                = $self->id_from_sku($setup->{to}->{shipping_charge_sku})
                || plan skip_all => <<EOS
SKIPPING the case ($case->{description}):
    Need a 'to' shipping charge for this test case.
    (this might well be normal data for a DC)
EOS
            ;

            my ($shipment, $response_or_data) = Test::XTracker::Data::Order->create_shipment_and_response(
                $self->{channel},
                {
                    %{$setup->{from}},
                    shipping_charge_id => $self->id_from_sku($setup->{from}->{shipping_charge_sku}),
                },
                $self->premier_shipping_charge,
            );

            # set the Customer Category
            my $customer = $shipment->order->customer;
            $customer->update( { category_id => delete $setup->{from}{customer_category} } );

            # make the Shipping Charge ZERO which should definetly cause the
            # Shipping Charge to change when we want it to
            # (if the change is within +/- 3 of the original then no change is made)
            $shipment->update( { shipping_charge => 0 } );

            # get rid of any Renumerations for the Shipment so
            # that we can easily spot new ones that get created
            _delete_shipment_renumerations( $shipment );

            note 'Run';

            my $framework = $self->{framework};
            my $mech = $framework->mech;
            XT::Net::WebsiteAPI::TestUserAgent->with_get_response(
                $response_or_data,
                sub { $framework->flow_mech__customercare__edit_shipment($shipment) },
            );

            $mech->form_name("editShipment");
            $mech->select(shipping_charge_id => $to_shipping_charge_id);
            if ( my $nominated_delivery_date = $setup->{to}->{nominated_delivery_date} ) {
                # Here we have to insist the value exists since $mech
                # might not know about it (sometimes it's not rendered,
                # sometimes it's replaced client side)
                $mech->current_form->force_field(
                    nominated_delivery_date => $self->nominated_delivery_date,
                );
            }

            XT::Net::WebsiteAPI::TestUserAgent->with_get_response(
                $response_or_data,
                sub { $mech->submit() },
            );

            note 'Test';

            note("Test Web page");
            like(
                $mech->uri . "",
                qr|/CustomerCare/OrderSearch/OrderView|,
                "Ended up on the correct resulting URI",
            );
            if ( my $error_message = $expected->{error_message} ) {
                like(
                    $mech->content,
                    qr/$error_message/sm,
                    "  and the correct error message is present",
                );
                return; # Error message ==> nothing more to test here
            }
            else {
                if ( $mech->content =~ m{<p class="error_msg".*?>\s*(.+?)\s*</p>} ) {
                    my $error = $1;
                    fail("Didn't expect any error messages, but encountered one anyway:\nERROR($error)\n");
                    return; # Unexpected Error message ==> no point in testing anything else
                }
            }


            note("Test DB");
            my $old_sla_cutoff      = $shipment->sla_cutoff;
            $shipment->discard_changes();

            is(
                $shipment->premier_routing->code,
                $expected->{premier_routing_code},
                "premier_routing_code ok",
            );

            my $new_shipping_charge = $shipment->shipping_charge_table->charge;
            # as these Shipments are paid with using Store Credit
            # then a Debit/Refund Renumeration will be created
            # to either charge/refund the Customer the difference
            my $shipment_renum_rs = $shipment->search_related( 'renumerations', {
                # because of Taxes the actual amount charged could be more than the basic cost so
                # search using a minimum (remember the charge is negative so actually use a maximum)
                shipping                => { '<=' => $new_shipping_charge },
                renumeration_type_id    => $RENUMERATION_TYPE__CARD_DEBIT,
                renumeration_class_id   => $RENUMERATION_CLASS__ORDER,
                renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
            } );

            if ( $expected->{change_in_shipping_charge} ) {
                cmp_ok( $shipment_renum_rs->count, '==', 1, "New Shipping Cost has been Charged" );
            }
            else {
                cmp_ok( $shipment_renum_rs->count, '==', 0, "New Shipping Cost has NOT been Charged" );
            }
        };
    }
}

sub id_from_sku {
    my ($self, $shipping_charge_sku) = @_;
    my $shipping_charge = $self->schema->resultset("Public::ShippingCharge")->search({
        sku => $shipping_charge_sku,
    })->first or return undef;
    return $shipping_charge->id;
}

sub _delete_shipment_renumerations {
    my $shipment = shift;

    my @renums = $shipment->renumerations->all;
    foreach my $renum ( @renums ) {
        $renum->renumeration_items->delete;
        $renum->renumeration_change_logs->delete;
        $renum->renumeration_status_logs->delete;
        $renum->link_return_renumerations->delete;
        $renum->renumeration_tenders->delete;
        $renum->delete;
    }

    return $shipment->discard_changes;
}

=head2 test_edit_shipment_force_manual_booking

Test that setting/unsetting the force manual booking sets the flags correctly.

=cut

sub test_edit_shipment_force_manual_booking : Tests {
    my $self = shift;

    my $framework = $self->{framework};

    # Create a shipment so we can access its edit shipment page
    my $shipment = $framework->picked_order->{shipment_object};
    for (
        [ 'rtcb off turns on forces manual booking' => {
            shipment => {
                force_manual_booking => 0,
                has_valid_address    => 0,
            },
            post => {
                rtcb        => 0,
                rtcb_reason => 'test reason',
            },
            expected => {
                force_manual_booking => 1,
                has_valid_address    => 0,
            },
        }, ],
        [ 'rtcb on turn off force manual booking' => {
            shipment => {
                force_manual_booking => 1,
            },
            post => {
                rtcb => 1,
                rtcb_reason => 'test reason',
            },
            expected => {
                force_manual_booking => 0,
            },
        }, ],
    ) {
        my ( $test_name, $args ) = @$_;
        subtest $test_name => sub {
            $shipment->update($args->{shipment});

            $framework->flow_mech__customercare__edit_shipment($shipment)
                ->flow_mech__customercare__edit_shipment_submit($args->{post});

            $shipment->discard_changes;

            for my $field ( keys %{$args->{expected}} ) {
                if ( $args->{expected}{$field} ) {
                    ok( $shipment->$field, "$field should be true" );
                }
                else {
                    ok( !$shipment->$field, "$field should be false" );
                }
            }
        };
    }
}
