#!/usr/bin/perl
use NAP::policy qw/test/;

use List::Util qw/ first /;

# load the module that provides all of the common test functionality
use FindBin::libs;

use Test::XTracker::Data;
use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::ShippingCharge',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                sku
                description
                charge
                currency_id
                flat_rate
                class_id
                premier_routing_id
                latest_nominated_dispatch_daytime
                channel_id
                is_enabled
                is_return_shipment_free
                is_express
                is_slow
                is_customer_facing
            ]
        ],

        relations => [
            qw[
                channel
                shipping_charge_class
                currency
                postcode_shipping_charges
                state_shipping_charges
                country_shipping_charges
                premier_routing
                shipping_description
                region_charges
                country_charges
                ups_service_availabilities
                shipping_charge_late_postcodes
                ship_restriction_allowed_shipping_charges
                delivery_date_restrictions
                shipments
                pre_orders
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                find_by_sku
                find_unknown
                find_by_channel_sku
                enabled
            ]
        ],
    }
);


note('Make sure the inflated datatypes are ok');
my $schema = Test::XTracker::Data->get_schema;
my $shipping_charge_rs = $schema->resultset("Public::ShippingCharge");

# Any shipping_charge with a dispatch daytime will do
my $shipping_charge_row = $shipping_charge_rs->search({
    latest_nominated_dispatch_daytime => { '!=' =>  undef },
})->first;

SKIP: {
    skip('No nominated day shipping charges in this database', 6) unless $shipping_charge_row;
    my $latest_nominated_dispatch_daytime =
            $shipping_charge_row->latest_nominated_dispatch_daytime;
    isa_ok(
        $latest_nominated_dispatch_daytime,
        "DateTime::Duration",
        "Column value of latest_nominated_dispatch_daytime isa Duration",
    );

    cmp_ok(
        $latest_nominated_dispatch_daytime->in_units("hours"), '>=', 11,
        "latest_nominated_dispatch_daytime has a reasonable value",
    );




    note('*** get_all_nominated_day_id_description');
    note('Check the general shape of the data structure, not the entire dataset (which will change a lot)');
    note('Note: this may change if we decide to group the charges on a specific group or group_description or whatnot, instead of the shipping_charge.description like now');
    my $shipping_charges
        = $schema->resultset("Public::ShippingCharge")
        ->get_all_nominated_day_id_description();
    cmp_ok(
        scalar @$shipping_charges,
        ">=",
        2,
        "Got at least two Shipping Charges (the Premier Evening and Daytime)",
    );

    my $premier_shipping_charge = first { $_->{description} =~ /Premier/ } @$shipping_charges;
    ok($premier_shipping_charge, "Found at least one Premier Shipping Charge");
    eq_or_diff(
        [ sort keys %$premier_shipping_charge ],
        [ "composite_id", "description" ],
        "  and it has the correct keys",
    );
    like(
        $premier_shipping_charge->{composite_id},
        qr/^\d+(-\d+)?(-\d+)?$/,  # Three channels: NAP, OUT, MRP (or one on DC3 atm)
        "    and the composite_id is well formed",
    );
}

$schematest->run_tests();
