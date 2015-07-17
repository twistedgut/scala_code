#!/usr/bin/perl

use NAP::policy "tt";

# load the module that provides all of the common test functionality
use FindBin::libs;
use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::PutawayPrepContainer',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                container_id
                user_id
                putaway_prep_status_id
                created
                modified
                destination
                failure_reason
            ]
        ],

        relations => [
            # belongs_to
            # has_many
            qw[
                container
                putaway_prep_status
                putaway_prep_inventories
                destination
                operator
            ]
        ],

        custom => [
            # methods in the Result class
            qw[
                remove_sku
            ]
        ],

        resultsets => [
            # methods in the ResultSet class
            qw[
                start
                add_sku
                finish
                find_in_progress
                find_in_transit
                find_incomplete
            ]
        ],
    }
);

$schematest->run_tests();
