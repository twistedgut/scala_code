#!/usr/bin/perl

use NAP::policy "tt";

# load the module that provides all of the common test functionality
use FindBin::libs;
use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::PutawayPrepInventory',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                putaway_prep_container_id
                pgid
                variant_id
                quantity
                voucher_variant_id
                putaway_prep_group_id
            ]
        ],

        relations => [
            # belongs_to
            # has_many
            qw[
                putaway_prep_group
                putaway_prep_container
                outer_variant
                outer_voucher_variant
                variant
                voucher_variant
            ]
        ],

        custom => [
            # methods in the Result class
            qw[
                variant_with_voucher
                inventory_group_data_for_putaway_admin
            ]
        ],

        resultsets => [
            # methods in the ResultSet class
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
