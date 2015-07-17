#!/usr/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

# load the module that provides all of the common test functionality
use FindBin::libs;
use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::Country',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                code
                country
                sub_region_id
                proforma
                returns_proforma
                currency_id
                shipping_zone_id
                dhl_tariff_zone
                local_currency_code
                phone_prefix
                is_commercial_proforma
            ]
        ],

        relations => [
            qw[
                currency
                country_promotion_type_welcome_packs
                country_shipment_types
                country_shipping_charges
                country_tax_codes
                country_tax_rate
                price_countries
                shipping_attributes
                tax_rule_values
                sub_region
                postcode_shipping_charges
                country_duty_rates
                return_country_refund_charges
                product_type_tax_rates
                duty_rule_values
                country_subdivisions
                link_marketing_promotion__countries
                ship_restriction_exclude_postcodes
                ship_restriction_allowed_countries
                local_exchange_rates
                state_shipping_charges
                returns_charges
                shipping_charge_late_postcodes
                country_charges
            ]
        ],

        custom => [
            qw[
                welcome_pack
                can_refund_for_return
                no_charge_for_exchange
                address_formatting_messages
            ]
        ],

        resultsets => [
            qw[
                get_exchange_countries
                by_name
                find_code
                add
                find_by_name
                valid_countries_for_editing_address
            ]
        ],
    }
);

$schematest->run_tests();

