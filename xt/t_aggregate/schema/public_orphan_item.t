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
        moniker   => 'Public::OrphanItem',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                variant_id
                voucher_variant_id
                container_id
                operator_id
                date
                old_container_id
            ]
        ],

        relations => [
            qw[
                container
                variant
                voucher_variant
                operator
            ]
        ],

        custom => [
            qw[
                orphan_item_into
                unpick
                get_sku
                get_product_id
                get_channel
                get_true_variant
            ]
        ],

        resultsets => [
            qw[
                create_orphan_item
                unpick
                items_in_container
                container_ids
                containers
            ]
        ],
    }
);

$schematest->run_tests();
