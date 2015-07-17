#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::RunCondition(
    export   => qw( $distribution_centre ),
);

=head1 DESCRIPTION

This tests EditAddress and UpdateAddress, specifically the Select
Shipping Option screen and update.

=cut

use HTML::Form::Extras;


use Test::Differences;
use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XTracker::Data::Shipping;
use Test::XTracker::Data::Order;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :customer_category
    :shipment_status
    :shipment_item_status
    :shipment_type
    :shipping_charge_class
    :ship_restriction
);

use XTracker::Database qw( :common xtracker_schema );

use XT::Net::WebsiteAPI::TestUserAgent;
use XT::Data::DateStamp;
use XTracker::Order::Actions::ConfirmAddress;

my $dc     = $distribution_centre;

my $schema = xtracker_schema();
my $count = $schema->resultset('Public::ShippingCharge')->search({ latest_nominated_dispatch_daytime => { '!=', undef }} )->count;

if( !$count > 0 ) {
    #nominated day delivery is not set for any of the sku's
    #so skip
    plan skip_all => "Skipping Test as nominated day delivery functionality is not switched 'On'";
}

if( $dc eq 'DC1') {
    plan skip_all => "Skipping Test as until UK Standard goes live as this test relies on the current configuration :(";
}


test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        "Test::XT::Flow::CustomerCare",
    ],
);

$framework->login_with_permissions({
    perms => {
        $AUTHORISATION_LEVEL__MANAGER => [
            "Customer Care/Order Search",
        ],
   },
    dept => "Shipping",
});
$framework->mech->force_datalite(1);


test_prefix("Setup: order shipment");

# Test the Premier Nominated Day stuff with NAP and the Non-Premier
# Nominated Day with MRP INTL (the first Channel to get it)

my $NAP_channel = Test::XTracker::Data->channel_for_nap();
my $MRP_channel = Test::XTracker::Data->channel_for_mrp();
my $mech = $framework->mech;

my $shipping_charge_rs = $schema->resultset("Public::ShippingCharge");
my $NAP_non_premier_shipping_charge_sku = {
    # These are valid NAP skus for the current_dc address
    DC1 => "9000420-001", # UK Standard
    DC2 => "900065-002", # Kentucky 3-5 Business Days
    DC3 => "9000311-001", # Standard 2 days Hong Kong
}->{$dc} or die("Unknown DC ($dc)");
my $NAP_non_premier_shipping_charge = $shipping_charge_rs->search({
    sku        => $NAP_non_premier_shipping_charge_sku,
    channel_id => $NAP_channel->id,
})->first or die("Could not find sku");

my $NAP_in_dc_non_premier_shipping_charge_sku = {
    # These are valid (non-premier) NAP skus for the current_dc address
    DC1 => "9000420-001", # UK Standard
    DC2 => "900032-001", # New York Next Business Day
    DC3 => "9000311-001", # Standard 2 days Hong Kong
}->{$dc} or die("Unknown DC ($dc)");
my $NAP_in_dc_non_premier_shipping_charge = $shipping_charge_rs->search({
    sku        => $NAP_in_dc_non_premier_shipping_charge_sku,
    channel_id => $NAP_channel->id,
})->first or die("Could not find sku");

# get Premier Routing records by Code
my %premier_routing_recs = map { $_->code => $_ }
                                $schema->resultset('Public::PremierRouting')->all;
my $premier_routing = {
    # Daytime
    id          => $premier_routing_recs{D}->id,
    description => $premier_routing_recs{D}->description,
};
my $NAP_premier_shipping_charge = Test::XTracker::Data::Order->get_premier_shipping_charge(
    $NAP_channel,
    $premier_routing,
);

my $MRP_express_nom_shipping_charge_id;
my $MRP_express_nom_shipping_charge_description;
my $MRP_non_premier_shipping_charge_id;
my $MRP_non_premier_shipping_charge_description;
if( $MRP_channel->is_enabled ) {
my $MRP_non_premier_shipping_charge_sku = {
    # These are valid MRP skus for the current_dc address
    DC1 => "9000421-001", # UK Standard
    DC2 => "910065-001", # Kentucky 3-5 Business Days
}->{$dc} or die("Unknown DC ($dc)");
my $MRP_non_premier_shipping_charge = $shipping_charge_rs->search({
    sku        => $MRP_non_premier_shipping_charge_sku,
    channel_id => $MRP_channel->id,
})->first or die("Could not find sku");
# These will fail on DC2 until MRP-INTL gets Nominated Day
 $MRP_non_premier_shipping_charge_id = eval {
    $MRP_non_premier_shipping_charge->id;
};
 $MRP_non_premier_shipping_charge_description = eval {
    $MRP_non_premier_shipping_charge->description;
};

my $MRP_express_nom_shipping_charge_sku = {
    # These are valid MRP skus for the current_dc address
    DC1 => "9000216-001", # UK Express - Nominated Day
    DC2 => undef, # Doesn't exist yet
}->{$dc};
my $MRP_express_nom_shipping_charge = $shipping_charge_rs->search({
    sku        => $MRP_express_nom_shipping_charge_sku,
    channel_id => $MRP_channel->id,
})->first;
# These will fail on DC2 until MRP-INTL gets Nominated Day
 $MRP_express_nom_shipping_charge_id = eval {
    $MRP_express_nom_shipping_charge->id;
};
$MRP_express_nom_shipping_charge_description = eval {
    $MRP_express_nom_shipping_charge->description;
};


}
my $NAP_international_shipping_charge_sku = {
    # These are valid NAP skus for sending to Chile and Argentina
    DC1 => "900000-001",  # International
    DC2 => "9000203-001", # Central and South America
    DC3 => "9000321-001", # Global standard (3-5 days) Rest of the world
}->{$dc} or die("Unknown DC ($dc)");
my $NAP_international_shipping_charge = $shipping_charge_rs->search({
    sku        => $NAP_international_shipping_charge_sku,
    channel_id => $NAP_channel->id,
})->first or die("Could not find sku");




# Test the different display outcomes for the date/dropdown/error message, etc.
my $nominated_delivery_date = "2011-09-15";
my $nominated_selection_date = "2011-09-14";

# Easily distinguishable amount
my $tax_amount            = "13.120";
my $shipping_price_amount = "3.460";



# Test the Select Shipping Option page, The Confirmation page, and the final update
my $select_shipping_option_page_test_cases = [
    # Shipping Options, and Nominated Day Delivery date
    {
        prefix      => "NAP: Pre, Nom=>Dom",
        description => "NAP-Premier, Nominated Day: has delivery date, has premier routing",
        setup => {
            channel => $NAP_channel,
            current => {
                address_in               => "current_dc_premier",
                shipment_type            => $SHIPMENT_TYPE__PREMIER,
                nominated_delivery_date  => $nominated_delivery_date,
                shipping_charge_id       => $NAP_premier_shipping_charge->id,
                available_delivery_dates => [ $nominated_delivery_date ],
            },
            new => {
                address_in => "current_dc",
            },
        },
        expected => {
            current => {
                "Shipping Option"   => $NAP_premier_shipping_charge->description,
                "Nom Delivery Date" => Test::XTracker::Data::Shipping->to_uk_web_date_format(
                    $nominated_delivery_date,
                ),
                "Delivery Option"   => $premier_routing->{description},
            },
            select_shipping_option => {
                "Shipping Option" => {
                    DC1 => {
                        default_shipping_charge_description => "UK Standard",
                        shipping_charge_descriptions        => [
                            "Courier Special Delivery",
                            "UK Express",
                            "UK Express - Nominated Day",
                            "UK Standard"
                        ],
                    },
                    DC2 => {
                        default_shipping_charge_description => "Kentucky 3-5 Business Days",
                        shipping_charge_descriptions        => [
                            "Courier Special Delivery",
                            "Kentucky 3-5 Business Days",
                            "Kentucky Next Business Day",
                            ],
                   },
                   DC3 => {
                        default_shipping_charge_description => "Standard 2 days Hong Kong",
                        shipping_charge_descriptions        => [
                            "Standard 2 days Hong Kong",
                        ],
                  },
                },
                nominated_delivery_date => $nominated_delivery_date,
            },
            confirmation => {
                "Shipping Option"   =>  {
                    input_name  => "selected_shipping_charge_id",
                    value       => $NAP_non_premier_shipping_charge->description,
                    input_value => $NAP_non_premier_shipping_charge->id,
                },
                "Nom Delivery Date" => { # The default from the original address
                    input_name  => "selected_nominated_delivery_date",
                    value       => "",
                    input_value => "",
                },
                "Delivery Option"   => "",
            },
            final => {
                shipping_charge_id           => $NAP_non_premier_shipping_charge->id,
                shipping_account_name        => "Domestic",
                shipment_type                => "Domestic",
                nominated_delivery_date      => undef,
                shipment_note                => {
                    DC1 => { shipment_note_qr => qr|\QAddress(some one, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, London, NW10 4GR, United Kingdom => Bert Ernieson, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, London, BN1 9RF, United Kingdom), Nominated Delivery Date(15/09/2011 => ), Shipment Type(Premier => Domestic), Shipping Charge(Premier Daytime => UK Standard), Shipping Charge Price(\E\d+\.\d+\Q => \E\d+\.\d+\Q), Shipping SKU(9000210-001 => 9000420-001)| },
                    DC2 => { shipment_note_qr => qr|\QAddress(some one, 725 Darlington Avenue, Mahwah, NJ, New Jersey, NY, 11371, United States => Bert Ernieson, 725 Darlington Avenue, Mahwah, NJ, New Jersey, KY, 42201, United States), Nominated Delivery Date(15/09/2011 => ), Shipment Type(Premier => Domestic), Shipping Charge(Premier Daytime => Kentucky 3-5 Business Days), Shipping Charge Price(\E\d+\.\d+\Q => \E\d+\.\d+\Q), Shipping SKU(9000211-001 => 900065-002)| },
                    DC3 => { shipment_note_qr => qr|\QAddress(some one, Interlink Building, 10th floor, 35-47 Tsing Yi Road, Tsing Yi, New Territories, Hong Kong, Hong Kong, Aberdeen, Hong Kong => Bert Ernieson, Interlink Building, 10th floor, 35-47 Tsing Yi Road, Tsing Yi, New Territories, Hong Kong, Hong Kong, Tai Wo, Hong Kong), Nominated Delivery Date(15/09/2011 => ), Shipment Type(Premier => Domestic), Shipping Charge(Premier Daytime => Standard 2 days Hong Kong), Shipping Charge Price(\E\d+\.\d+\Q => \E\d+\.\d+\Q), Shipping SKU(9000324-001 => 9000311-001)| },

                },
            },
        },
    },
    {
        prefix      => "NAP: Dom=>Pre, Nom",
        description => "NAP - Domestic: no delivery date, no premier routing",
        setup => {
            channel => $NAP_channel,
            current => {
                address_in               => "current_dc",
                shipment_type            => $SHIPMENT_TYPE__DOMESTIC,
                nominated_delivery_date  => undef,
                shipping_charge_id       => $NAP_non_premier_shipping_charge->id,
                available_delivery_dates => [ $nominated_delivery_date ],
            },
            new => {
                address_in              => "current_dc_premier",
                nominated_delivery_date => $nominated_delivery_date,
                shipping_charge_id      => $NAP_premier_shipping_charge->id,
            },
        },
        expected => {
            current => {
                "Shipping Option"   => $NAP_non_premier_shipping_charge->description,
                "Nom Delivery Date" => "",
                "Delivery Option"   => "",
            },
            select_shipping_option => {
                "Shipping Option" => {
                    DC1 => {
                        default_shipping_charge_description => "UK Standard",
                        shipping_charge_descriptions        => [
                            "Courier Special Delivery",
                            "FAST TRACK: Premier Anytime",
                            "Premier Daytime",
                            "Premier Evening",
                            "UK Express",
                            "UK Standard"
                        ],
                    },
                    DC2 => {
                        default_shipping_charge_description => "New York 3-5 Business Days",
                        shipping_charge_descriptions        => [
                            "Courier Special Delivery",
                            "FAST TRACK: Premier Anytime",
                            "New York 3-5 Business Days",
                            "New York Next Business Day",
                            "Premier Daytime",
                            "Premier Evening",
                        ],
                    },
                    DC3 => {
                    default_shipping_charge_description => "Standard 2 days Hong Kong",
                        shipping_charge_descriptions        => [
                            'FAST TRACK: Premier Anytime',
                            'Premier Daytime',
                            'Premier Evening',
                            'Standard 2 days Hong Kong',
                        ],

                    }
                },
                nominated_delivery_date => "",
            },
            confirmation => {
                "Shipping Option"   =>  {
                    input_name  => "selected_shipping_charge_id",
                    value       => $NAP_premier_shipping_charge->description,
                    input_value => $NAP_premier_shipping_charge->id,
                },
                "Nom Delivery Date" => { # The default from the original address
                    input_name  => "selected_nominated_delivery_date",
                    value       => Test::XTracker::Data::Shipping->to_uk_web_date_format(
                        $nominated_delivery_date,
                    ),
                    input_value => $nominated_delivery_date,
                },
                    ,
                "Delivery Option"   => $premier_routing->{description},
            },
            final => {
                shipping_charge_id           => $NAP_premier_shipping_charge->id,
                shipping_account_name        => "Unknown", # Premier
                shipment_type                => "Premier",
                nominated_delivery_date      => $nominated_delivery_date,
                shipment_note                => {
                    DC1 => { shipment_note_qr => qr|\QAddress(some one, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, London, BN1 9RF, United Kingdom => Bert Ernieson, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, London, NW10 4GR, United Kingdom), Nominated Delivery Date( => 15/09/2011), Shipment Type(Domestic => Premier), Shipping Charge(UK Standard => Premier Daytime), Shipping Charge Price(\E\d+\.\d+\Q => \E\d+\.\d+\Q), Shipping SKU(9000420-001 => 9000210-001)| },
                    DC2 => { shipment_note_qr => qr|\QAddress(some one, 725 Darlington Avenue, Mahwah, NJ, New Jersey, KY, 42201, United States => Bert Ernieson, 725 Darlington Avenue, Mahwah, NJ, New Jersey, NY, 11371, United States), Nominated Delivery Date( => 15/09/2011), Shipment Type(Domestic => Premier), Shipping Charge(Kentucky 3-5 Business Days => Premier Daytime), Shipping Charge Price(\E\d+\.\d+\Q => \E\d+\.\d+\Q), Shipping SKU(900065-002 => 9000211-001)| },
                    DC3=> { shipment_note_qr => qr|\Qsome one, Interlink Building, 10th floor, 35-47 Tsing Yi Road, Tsing Yi, New Territories, Hong Kong, Hong Kong, Tai Wo, Hong Kong => Bert Ernieson, Interlink Building, 10th floor, 35-47 Tsing Yi Road, Tsing Yi, New Territories, Hong Kong, Hong Kong, Aberdeen, Hong Kong), Nominated Delivery Date( => 15/09/2011), Shipment Type(Domestic => Premier), Shipping Charge(Standard 2 days Hong Kong => Premier Daytime), Shipping Charge Price(\E\d+\.\d+\Q => \E\d+\.\d+\Q), Shipping SKU(9000311-001 => 9000324-001)| },
                },
            },
        },
    },
    {
        run_condition => [ "DC1" ], # Only INTL has Express Nominated Day at the moment
        prefix        => "MRP: Dom=>Express, Nom",
        description   => "MRP - Domestic: no delivery date, no premier routing",
        setup => {
            channel => $MRP_channel,
            current => {
                address_in               => "current_dc",
                shipment_type            => $SHIPMENT_TYPE__DOMESTIC,
                nominated_delivery_date  => undef,
                shipping_charge_id       => $MRP_non_premier_shipping_charge_id,
                available_delivery_dates => [ $nominated_delivery_date ],
            },
            new => {
                address_in              => "current_dc_other",
                nominated_delivery_date => $nominated_delivery_date,
                shipping_charge_id      => $MRP_express_nom_shipping_charge_id,
            },
        },
        expected => {
            current => {
                "Shipping Option"   => $MRP_non_premier_shipping_charge_description,
                "Nom Delivery Date" => "",
                "Delivery Option"   => "",
            },
            select_shipping_option => {
                "Shipping Option" => {
                    DC1 => {
                        default_shipping_charge_description => "UK Standard",
                        shipping_charge_descriptions        => [
                            "Courier Special Delivery",
                            "UK Express",
                            "UK Express - Nominated Day",
                            "UK Standard"
                        ],
                    },
                    DC2 => undef, # Not yet available in DC2
                },
                nominated_delivery_date => "",
            },
            confirmation => {
                "Shipping Option"   =>  {
                    input_name  => "selected_shipping_charge_id",
                    value       => $MRP_express_nom_shipping_charge_description,
                    input_value => $MRP_express_nom_shipping_charge_id,
                },
                "Nom Delivery Date" => { # The default from the original address
                    input_name  => "selected_nominated_delivery_date",
                    value       => Test::XTracker::Data::Shipping->to_uk_web_date_format(
                        $nominated_delivery_date,
                    ),
                    input_value => $nominated_delivery_date,
                },
                "Delivery Option"   => "",
            },
            final => {
                shipping_charge_id           => $MRP_express_nom_shipping_charge_id,
                shipping_account_name        => "Domestic",
                shipment_type                => "Domestic",
                nominated_delivery_date      => $nominated_delivery_date,
                shipment_note                => {
                    DC1 => { shipment_note_qr => qr|\QAddress(some one, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, London, BN1 9RF, United Kingdom => Bert Ernieson, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, London, S10 2TG, United Kingdom), Nominated Delivery Date( => 15/09/2011), Shipping Charge(UK Standard => UK Express - Nominated Day), Shipping Charge Price(\E\d+\.\d+\Q => \E\d+\.\d+\Q), Shipping SKU(9000421-001 => 9000216-001)| },
                    DC2 => undef, # Not yet available in DC2
                },
            },
        },
    },


    # Pricing and recalculation of tax
    {
        prefix      => "NAP: Only address change",
        description => "NAP - Only address change => no Shipping Charge change, no tax change",
        setup => {
            channel => $NAP_channel,
            current => {
                address_in               => "current_dc",
                shipment_type            => $SHIPMENT_TYPE__DOMESTIC,
                nominated_delivery_date  => undef,
                shipping_charge_id       => $NAP_non_premier_shipping_charge->id,
                available_delivery_dates => [ $nominated_delivery_date ],
            },
            new => {
                address_in => "current_dc",
            },
        },
        expected => {
            current => {
                "Shipping Option"   => $NAP_non_premier_shipping_charge->description,
            },
            final => {
                shipping_charge_id           => $NAP_non_premier_shipping_charge->id,
                shipping_account_name        => "Domestic",
                shipment_type                => "Domestic",
                nominated_delivery_date      => undef,
                should_shipping_price_change => 0, # No, no shipping charge change
                should_item_tax_change       => 0, # No, no country or state change
            },
        },
    },
    {
        prefix      => "NAP: Country change",
        description => "NAP - Country => Shipping Charge change, Tax change",
        setup => {
            channel => $NAP_channel,
            current => {
                address_in               => "AmWorld",
                shipment_type            => $SHIPMENT_TYPE__INTERNATIONAL,
                nominated_delivery_date  => undef,
                shipping_charge_id       => $NAP_international_shipping_charge->id,
                available_delivery_dates => [ $nominated_delivery_date ],
            },
            new => {
                address_in => "AmWorldDifferentCountry",
            },
        },
        expected => {
            current => {
                "Shipping Option"   => $NAP_international_shipping_charge->description,
            },
            final => {
                shipping_charge_id           => $NAP_international_shipping_charge->id,
                shipping_account_name        => "International",
                shipment_type                => "International",
                nominated_delivery_date      => undef,
                should_shipping_price_change => 1, # yes, country change implies shipping charge recalc (even if it might be the same)
                should_item_tax_change       => 1, # yes, country or state change
            },
        },
    },
    {
        prefix      => "NAP: Country change for EIP Customer",
        description => "NAP - Country => No Shipping Charge change for EIP Customer",
        setup => {
            channel => $NAP_channel,
            customer_category => $CUSTOMER_CATEGORY__EIP,
            current => {
                address_in               => "AmWorld",
                shipment_type            => $SHIPMENT_TYPE__INTERNATIONAL,
                nominated_delivery_date  => undef,
                shipping_charge_id       => $NAP_international_shipping_charge->id,
                available_delivery_dates => [ $nominated_delivery_date ],
            },
            new => {
                address_in => "AmWorldDifferentCountry",
            },
        },
        expected => {
            current => {
                "Shipping Option"   => $NAP_international_shipping_charge->description,
            },
            final => {
                shipping_charge_id           => $NAP_international_shipping_charge->id,
                shipping_account_name        => "International",
                shipment_type                => "International",
                nominated_delivery_date      => undef,
                should_shipping_price_change => 0, # no, not for EIPs
                should_item_tax_change       => 1, # yes, country or state change
            },
        },
    },
    {
        prefix      => "NAP: ShippingCharge change",
        description => "NAP - Same address, New Shipping Charge, same Country/State => Shipping Charge change, no Tax change",
        setup => {
            channel => $NAP_channel,
            current => {
                address_in               => "current_dc_premier",
                shipment_type            => $SHIPMENT_TYPE__PREMIER,
                nominated_delivery_date  => $nominated_delivery_date,
                shipping_charge_id       => $NAP_premier_shipping_charge->id,
                available_delivery_dates => [ $nominated_delivery_date ],
            },
            new => {
                address_in         => "current_dc_premier",
                shipping_charge_id => $NAP_in_dc_non_premier_shipping_charge->id,
            },
        },
        expected => {
            current => {
                "Shipping Option" => $NAP_premier_shipping_charge->description,
            },
            final => {
                shipping_charge_id           => $NAP_in_dc_non_premier_shipping_charge->id,
                shipping_account_name        => "Domestic",
                shipment_type                => "Domestic",
                nominated_delivery_date      => undef,
                should_shipping_price_change => 1, # Yes, Shipping Option changed
                should_item_tax_change       => 0, # No, no country or state change
            },
        },
    },
    {
        prefix      => "NAP: ShippingCharge No change for EIP Customer",
        description => "NAP - Same address, New Shipping Charge, same Country/State => No Shipping Charge change for EIP Customer, no Tax change",
        setup => {
            channel => $NAP_channel,
            customer_category => $CUSTOMER_CATEGORY__EIP_PREMIUM,
            current => {
                address_in               => "current_dc_premier",
                shipment_type            => $SHIPMENT_TYPE__PREMIER,
                nominated_delivery_date  => $nominated_delivery_date,
                shipping_charge_id       => $NAP_premier_shipping_charge->id,
                available_delivery_dates => [ $nominated_delivery_date ],
            },
            new => {
                address_in         => "current_dc_premier",
                shipping_charge_id => $NAP_in_dc_non_premier_shipping_charge->id,
            },
        },
        expected => {
            current => {
                "Shipping Option" => $NAP_premier_shipping_charge->description,
            },
            final => {
                shipping_charge_id           => $NAP_in_dc_non_premier_shipping_charge->id,
                shipping_account_name        => "Domestic",
                shipment_type                => "Domestic",
                nominated_delivery_date      => undef,
                should_shipping_price_change => 0, # No, not for EIP Customers
                should_item_tax_change       => 0, # No, no country or state change
            },
        },
    },
    {
        run_condition => [ "DC2" ], # no hazmat restrictions anymore
        prefix      => "NAP: HAZMAT Res",
        description => "NAP with HAZMAT Product Restrictions, NO Shipping Charges of Class 'Air' should be shown",
        setup => {
            channel => $NAP_channel,
            current => {
                address_in               => "current_dc_premier",
                shipment_type            => $SHIPMENT_TYPE__PREMIER,
                shipping_charge_id       => $NAP_premier_shipping_charge->id,
                nominated_delivery_date  => $nominated_delivery_date,
            },
            new => {
                address_in => "current_dc",
            },
        },
        expected => {
            current => {
                "Shipping Option"   => $NAP_premier_shipping_charge->description,
                "Nom Delivery Date" => Test::XTracker::Data::Shipping->to_uk_web_date_format(
                    $nominated_delivery_date,
                ),
                "Delivery Option"   => $premier_routing->{description},
            },
            select_shipping_option => {
                "Shipping Option" => {
                    DC1 => {
                        default_shipping_charge_description => "UK Express",
                        shipping_charge_descriptions        => [
                            "Courier Special Delivery",
                            "UK Express",
                            ],
                    },
                    DC2 => {
                        default_shipping_charge_description => "Kentucky 3-5 Business Days",
                        shipping_charge_descriptions        => [
                            "Courier Special Delivery",
                            "Kentucky 3-5 Business Days",
                            "Kentucky Next Business Day",
                            ],
                    }
                },
                nominated_delivery_date => $nominated_delivery_date,
            },
            confirmation => {
                "Shipping Option"   =>  {
                    input_name  => "selected_shipping_charge_id",
                    value       => $NAP_non_premier_shipping_charge->description,
                    input_value => $NAP_non_premier_shipping_charge->id,
                },
                "Nom Delivery Date" => { # The default from the original address
                    input_name  => "selected_nominated_delivery_date",
                    value       => "",
                    input_value => "",
                },
                "Delivery Option"   => "",
            },
            final => {
                shipping_charge_id           => $NAP_non_premier_shipping_charge->id,
                shipping_account_name        => "Domestic",
                shipment_type                => "Domestic",
                nominated_delivery_date      => undef,
                shipment_note                => {
                    DC1 => { shipment_note_qr => qr|\QAddress(some one, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, London, NW10 4GR, United Kingdom => Bert Ernieson, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, London, BN1 9RF, United Kingdom), Nominated Delivery Date(15/09/2011 => ), Shipment Type(Premier => Domestic), Shipping Charge(Premier Daytime => UK Express), Shipping Charge Price(\E\d+\.\d+\Q => \E\d+\.\d+\Q), Shipping SKU(9000210-001 => 900003-001)| },
                    DC2 => { shipment_note_qr => qr|\QAddress(some one, 725 Darlington Avenue, Mahwah, NJ, New Jersey, NY, 11371, United States => Bert Ernieson, 725 Darlington Avenue, Mahwah, NJ, New Jersey, KY, 42201, United States), Nominated Delivery Date(15/09/2011 => ), Shipment Type(Premier => Domestic), Shipping Charge(Premier Daytime => Kentucky 3-5 Business Days), Shipping Charge Price(\E\d+\.\d+\Q => \E\d+\.\d+\Q), Shipping SKU(9000211-001 => 900065-002)| },
                    DC3=> {shipment_note_qr => qr|\QAddress(some one,Abeerdeen, Hong Kong => Bert Ernieson, Hong Kong), Nominated Delivery Date( => 15/09/2011), Shipment Type(Domestic => Premier), Shipping Charge(Premier DayTime => Standard 2 days Hong Kong), Shipping Charge Price(\E\d+\.\d+\Q => \E\d+\.\d+\Q), Shipping SKU(9000324-001 => 9000311-001)| },



                },
            },
        },
    },
    {
        run_condition => [ "DC1" ], # only INTL has HAZMAT LQ restriction
        prefix      => "NAP: HAZMAT LQ Res",
        description => "NAP with HAZMAT LQ Product Restrictions, NO Shipping Charges of Class 'Air' should be shown",
        setup => {
            channel => $NAP_channel,
            restrictions => {
                ship_restrictions => [
                    $SHIP_RESTRICTION__HZMT_LQ,
                ],
            },
            current => {
                address_in               => "current_dc_premier",
                shipment_type            => $SHIPMENT_TYPE__PREMIER,
                shipping_charge_id       => $NAP_premier_shipping_charge->id,
                nominated_delivery_date  => $nominated_delivery_date,
            },
            new => {
                address_in => "current_dc",
            },
        },
        expected => {
            current => {
                "Shipping Option"   => $NAP_premier_shipping_charge->description,
                "Nom Delivery Date" => Test::XTracker::Data::Shipping->to_uk_web_date_format(
                    $nominated_delivery_date,
                ),
                "Delivery Option"   => $premier_routing->{description},
            },
            select_shipping_option => {
                "Shipping Option" => {
                    DC1 => {
                        default_shipping_charge_description => "UK Express",
                        shipping_charge_descriptions        => [
                            "Courier Special Delivery",
                            "UK Standard",
                            ],
                    },
                    DC2 => {
                        default_shipping_charge_description => "Kentucky 3-5 Business Days",
                        shipping_charge_descriptions        => [
                            "Courier Special Delivery",
                            "Kentucky 3-5 Business Days",
                            "Kentucky Next Business Day",
                            ],
                    }
                },
                nominated_delivery_date => $nominated_delivery_date,
            },
            confirmation => {
                "Shipping Option"   =>  {
                    input_name  => "selected_shipping_charge_id",
                    value       => $NAP_non_premier_shipping_charge->description,
                    input_value => $NAP_non_premier_shipping_charge->id,
                },
                "Nom Delivery Date" => { # The default from the original address
                    input_name  => "selected_nominated_delivery_date",
                    value       => "",
                    input_value => "",
                },
                "Delivery Option"   => "",
            },
            final => {
                shipping_charge_id           => $NAP_non_premier_shipping_charge->id,
                shipping_account_name        => "Domestic",
                shipment_type                => "Domestic",
                nominated_delivery_date      => undef,
                shipment_note                => {
                    DC1 => { shipment_note_qr => qr|\QAddress(some one, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, London, NW10 4GR, United Kingdom => Bert Ernieson, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, London, BN1 9RF, United Kingdom), Nominated Delivery Date(15/09/2011 => ), Shipment Type(Premier => Domestic), Shipping Charge(Premier Daytime => UK Express), Shipping Charge Price(\E\d+\.\d+\Q => \E\d+\.\d+\Q), Shipping SKU(9000210-001 => 900003-001)| },
                    DC2 => { shipment_note_qr => qr|\QAddress(some one, 725 Darlington Avenue, Mahwah, NJ, New Jersey, NY, 11371, United States => Bert Ernieson, 725 Darlington Avenue, Mahwah, NJ, New Jersey, KY, 42201, United States), Nominated Delivery Date(15/09/2011 => ), Shipment Type(Premier => Domestic), Shipping Charge(Premier Daytime => Kentucky 3-5 Business Days), Shipping Charge Price(\E\d+\.\d+\Q => \E\d+\.\d+\Q), Shipping SKU(9000211-001 => 900065-002)| },
                    DC3=> {shipment_note_qr => qr|\QAddress(some one,Abeerdeen, Hong Kong => Bert Ernieson, Hong Kong), Nominated Delivery Date( => 15/09/2011), Shipment Type(Domestic => Premier), Shipping Charge(Premier DayTime => Standard 2 days Hong Kong), Shipping Charge Price(\E\d+\.\d+\Q => \E\d+\.\d+\Q), Shipping SKU(9000324-001 => 9000311-001)| },



                },
            },
        },
    },
];



sub test_select_shipping_option_page {
    my ($test_cases) = @_;
    test_prefix("");
    note("*** Test select_shipping_option_page");

    my @channels = Test::XTracker::Data->get_enabled_channels()->all;
    my @enabled_channels;
    foreach my $channel ( @channels ) {
        push(@enabled_channels, $channel->config_name());
    }

    # Submit and Test Updated Shipment, Shipment Note
    for my $case (@$test_cases) {
        note("** $case->{description}");
        test_prefix("$case->{prefix} * Setup: ");
        my $setup = $case->{setup} || {};
        my $expected = $case->{expected};

        if(my $run_condition = $case->{run_condition}) {
            note "Running in ($distribution_centre)";
            my $matched_runcondition_count =
                grep { $_ eq $distribution_centre }
                @$run_condition;
            if( ! $matched_runcondition_count ) {
                note("Skipping this, not meant for this DC");
                next;
            }
        }

        note "*** Setup";
        my ($shipment_row, $response_or_data) = Test::XTracker::Data::Order->create_shipment_and_response(
            $setup->{channel},
            {
                shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
                shipment_status      => $SHIPMENT_STATUS__PROCESSING,
                %{$setup->{current}},
            },
            $NAP_premier_shipping_charge,
        );

        my $old_sla_cutoff = $shipment_row->sla_cutoff;
        $shipment_row->shipment_items->update_all({ tax => $tax_amount });
        $shipment_row->update({ shipping_charge => $shipping_price_amount });
        my $old_shipping_price = $shipping_price_amount;
        # set-up any restrictions
        Test::XTracker::Data::Order->set_item_shipping_restrictions(
            $shipment_row,
            $setup->{restrictions}
        );

        # set the Customer's Category to 'None'
        # and then change it if asked to in setup
        my $customer = $shipment_row->order->customer;
        $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );
        if ( $setup->{customer_category} ) {
            $customer->update( { category_id => $setup->{customer_category} } );
        }

        note("order_id(" . $shipment_row->order->id . "), shipment_id(" . $shipment_row->id . ")");




        test_prefix("$case->{prefix}: * Run");
        $mech->order_nr($shipment_row->order->order_nr);
        $mech->order_view_url;
        $mech->follow_link_ok({ text_regex => qr/Edit Shipping Address/ });

        # New step - choose address from the customer set
        $framework->flow_mech__customercare__choose_address();

        my $new_order_address = Test::XTracker::Data->create_order_address_in(
            $setup->{new}->{address_in},
            $setup->{new}->{address_in_args} || {},
        );
        my $address_fields = {
            first_name => "Bert",
            last_name  => "Ernieson",
            map { $_ => $new_order_address->$_ }
                qw/ address_line_1 address_line_2 towncity county postcode country /,
        };

        XT::Net::WebsiteAPI::TestUserAgent->with_get_response(
            $response_or_data,
            sub {
                $mech->submit_form_ok({
                    form_name => "editAddress",
                    with_fields => $address_fields,
                    button      => "submit"
                }, "Update the address" );
            },
        );
        $mech->no_feedback_error_ok;



        test_prefix("$case->{prefix} - Test Select");
        note("*** Test Select Shipping Option page");

        my $page_data = $mech->as_data("CustomerCare/OrderSearch/ConfirmAddress_SelectShippingOption");
        test_address_values(
            "Current",
            $case,
            $page_data->{current_address},
            $expected->{current},
        );

        my $new_address = $page_data->{new_address} || {};
        my $new_shipping_option = $new_address->{"Shipping Option"};
        my $expected_new_shipping_option = $expected->{select_shipping_option}->{"Shipping Option"}->{$dc};
        if($expected_new_shipping_option) {
            is(
                $new_shipping_option->{select_selected}->[1],
                $expected_new_shipping_option->{default_shipping_charge_description},
                "Default Shipping Option ok",
            );
            eq_or_diff(
                [
                    map { $_->[1] }
                        @{$new_shipping_option->{select_values}},
                ],
                $expected_new_shipping_option->{shipping_charge_descriptions},
                "Shipping Options ok",
            );
        }


        test_prefix("$case->{prefix} - Run Confirmation");
        note("*** Submit Confirmation page");
        XT::Net::WebsiteAPI::TestUserAgent->with_get_response(
            $response_or_data,
            sub { $mech->form_name("editAddress") },
        );

        if(defined($setup->{new}->{shipping_charge_id})) {
            $mech->select(
                "selected_shipping_charge_id",
                $setup->{new}->{shipping_charge_id},
            );
        }
        if(defined($setup->{new}->{nominated_delivery_date})) {
            # Here we have to insist the value exists since $mech
            # might not know about it (sometimes it's not rendered,
            # sometimes it's replaced client side)
            $mech->current_form->force_field(
                selected_nominated_delivery_date => $setup->{new}->{nominated_delivery_date},
            );
        }

        XT::Net::WebsiteAPI::TestUserAgent->with_get_response(
            $response_or_data,
            sub { $mech->submit_form() },
        );



        test_prefix("$case->{prefix} - Test Confirmation");
        note("*** Test Confirmation page");

        $page_data = $mech->as_data("CustomerCare/OrderSearch/ConfirmAddress_SelectShippingOption");

        test_address_values(
            "New Selected",
            $case,
            $page_data->{new_address},
            $expected->{confirmation},
        );



        test_prefix("$case->{prefix} - Run UpdateAddress");
        note("*** Submit UpdateAddress");
        $mech->form_name("editAddress");
        XT::Net::WebsiteAPI::TestUserAgent->with_get_response(
            $response_or_data,
            sub { $mech->submit_form() },
        );
        $shipment_row->discard_changes();


        test_prefix("$case->{prefix} - Test UpdateAddress");
        note("*** Test UpdateAddress");
        my $final = $expected->{final};
        is(
            $shipment_row->shipping_charge_id,
            $final->{shipping_charge_id},
            "Shipping Charge id ok",
        );
        is(
            XT::Data::DateStamp->from_datetime($shipment_row->nominated_delivery_date),
            $final->{nominated_delivery_date},
            "Nominated Delivery Date ok",
        );

        test_possible_change(
            "shipping_charge",
            $expected->{final}->{should_shipping_price_change},
            $shipment_row->shipping_charge,
            $old_shipping_price,
        );

        my $shipment_item_row = $shipment_row->shipment_items->first;
        $shipment_item_row->discard_changes;
        $shipment_item_row = $schema->resultset("Public::ShipmentItem")->find($shipment_item_row->id);

        test_possible_change(
            "item_tax",
            $expected->{final}->{should_item_tax_change},
            $shipment_item_row->tax,
            $tax_amount,
        );

        Test::XTracker::Data::Shipping->test_shipment_note(
            $shipment_row,
            $expected->{final}->{shipment_note}->{$dc},
        );

        is(
            $shipment_row->shipping_account->name,
            $final->{shipping_account_name},
            "Shipping Account name ok",
        );
        is(
            $shipment_row->shipment_type->type,
            $final->{shipment_type},
            "Shipment Type name ok",
        );

        Test::XTracker::Data::Order->clear_item_shipping_restrictions( $shipment_row );
    }
}

sub test_possible_change {
    my ($change_name, $is_expected_to_change, $current_value, $old_value) = @_;
    defined $is_expected_to_change or return;

    if ($is_expected_to_change) {
        isnt($current_value, $old_value, "$change_name changed");
    }
    else {
        is($current_value, $old_value, "$change_name remained the same");
    }
}

sub test_address_values {
    my ($description, $case, $actual_address, $expected_address) = @_;

    for my $key (keys %$expected_address) {
        my $val = $actual_address->{$key} // "";
        eq_or_diff(
            [ $val ],
            [ $expected_address->{$key} ],
            "$case->{prefix} - $description - ($key) is ok ($expected_address->{$key})",
        );
    }
}






my $should_recalculate_items_or_shipping_pricing_test_cases = [
    {
        description => "Same address, same Shipping Charge => 0",
        setup => {
            current_address_in         => "current_dc",
            new_address_in             => "current_dc",
            current_shipping_charge_id => 123,
            new_shipping_charge_id     => 123,
        },
        expected => {
            should_recalculate_items_or_shipping => 0,
            should_recalculate_items             => 0,
        },
    },
    {
        description => "Different Address, Same Country, same Shipping Charge => 0",
        setup => {
            current_address_in         => "LondonPremier",
            new_address_in             => "UK",
            current_shipping_charge_id => 123,
            new_shipping_charge_id     => 123,
        },
        expected => {
            should_recalculate_items_or_shipping => 0,
            should_recalculate_items             => 0,
        },
    },
    {
        description => "Same address, different Shipping Charge => 1",
        setup => {
            current_address_in         => "current_dc",
            new_address_in             => "current_dc",
            current_shipping_charge_id => 123,
            new_shipping_charge_id     => 124,
        },
        expected => {
            should_recalculate_items_or_shipping => 1,
            should_recalculate_items             => 0,
        },
    },
    {
        description => "Different Country, same Shipping Charge => 1",
        setup => {
            current_address_in         => "current_dc",
            new_address_in             => "IntlWorld",
            current_shipping_charge_id => 123,
            new_shipping_charge_id     => 123,
        },
        expected => {
            should_recalculate_items_or_shipping => 1,
            should_recalculate_items             => 1,
        },
    },
    {
        description => "Same Country US, Same State, same Shipping Charge => 0",
        setup => {
            current_address_in         => "US5",
            new_address_in             => "US2",
            current_shipping_charge_id => 123,
            new_shipping_charge_id     => 123,
        },
        expected => {
            should_recalculate_items_or_shipping => 0,
            should_recalculate_items             => 0,
        },
    },
    {
        # Shouldn't happen (shouldn't be able to use the same sku) the
        # shipping charge wouldn't be the same
        description => "Same Country US, Different State, same Shipping Charge => 1",
        setup => {
            current_address_in         => "US5",
            new_address_in             => "ManhattanPremier",
            current_shipping_charge_id => 123,
            new_shipping_charge_id     => 123,
        },
        expected => {
            should_recalculate_items_or_shipping => 1,
            should_recalculate_items             => 1,
        },
    },
];
sub test_should_recalculate_items_or_shipping_pricing {
    my ($test_cases) = @_;
    test_prefix("");
    note("*** Test should_recalculate_items_or_shipping_pricing");

    my @channels = Test::XTracker::Data->get_enabled_channels()->all;
    my @enabled_channels;
    foreach my $channel ( @channels ) {
        push(@enabled_channels, $channel->config_name());
    }
    for my $case (@$test_cases) {
        note("** $case->{description}");
        my $setup = $case->{setup} || {};
        my $expected = $case->{expected};

        my $current_address = {
            Test::XTracker::Data->create_order_address_in(
                $setup->{current_address_in},
            )->get_columns
        };
        my $new_address = {
            Test::XTracker::Data->create_order_address_in(
                $setup->{new_address_in},
            )->get_columns
        };

        my $should_recalculate_items_or_shipping
            = XTracker::Order::Actions::ConfirmAddress::should_recalculate_items_or_shipping_pricing(
                $current_address,
                $new_address,
                $setup->{current_shipping_charge_id},
                $setup->{new_shipping_charge_id},
            );
        is(
            $should_recalculate_items_or_shipping,
            $expected->{should_recalculate_items_or_shipping},
            "Correct should_recalculate_items_or_shipping_pricing",
        );

        my $should_recalculate_items
            = XTracker::Order::Actions::ConfirmAddress::should_recalculate_items_pricing(
                $current_address,
                $new_address,
            );
        is(
            $should_recalculate_items,
            $expected->{should_recalculate_items},
            "Correct should_recalculate_items",
        );
    }
}




# Run the tests
test_should_recalculate_items_or_shipping_pricing($should_recalculate_items_or_shipping_pricing_test_cases);
test_select_shipping_option_page($select_shipping_option_page_test_cases);

done_testing();
