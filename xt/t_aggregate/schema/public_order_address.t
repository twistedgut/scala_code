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
        moniker   => 'Public::OrderAddress',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                title
                first_name
                last_name
                address_line_1
                address_line_2
                address_line_3
                towncity
                county
                country
                postcode
                address_hash
                urn
                last_modified
            ]
        ],

        relations => [
            qw[
                orders
                shipments
                country_table
                shipment_address_log_changed_froms
                order_address_log_changed_froms
                address_change_log_change_froms
                sample_receivers
                shipment_address_log_changed_toes
                address_change_log_change_toes
                order_address_log_changed_toes
                pre_order_shipment_address_ids
                pre_order_invoice_address_ids
            ]
        ],

        custom => [
            qw[
                country_ignore_case
                is_eu_member_states
                comma_seperated_str
                as_carrier_string
                has_non_latin_1_characters
                in_vertex_area
                full_name
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
