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
        moniker   => 'Public::ShippingAttribute',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                product_id
                scientific_term
                country_id
                packing_note
                dangerous_goods_note
                weight
                box_id
                fabric_content
                legacy_countryoforigin
                fish_wildlife
                operator_id
                id
                cites_restricted
                fish_wildlife_source
                is_hazmat
                packing_note_operator_id
                packing_note_date_added
                length
                width
                height
            ]
        ],

        relations => [
            qw[
                country
                box
                product
                operator
                packing_note_operator
                audit_recents
            ]
        ],

        custom => [
            qw[
                add_volumetrics
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
