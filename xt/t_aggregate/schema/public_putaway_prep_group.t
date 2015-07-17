#!/usr/bin/perl

use NAP::policy "tt";

# load the module that provides all of the common test functionality
use FindBin::libs;
use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::PutawayPrepGroup',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                status_id
                group_id
                recode_id
                putaway_prep_cancelled_group_id
                putaway_prep_migration_group_id
            ]
        ],

        relations => [
            # belongs_to
            # has_many
            qw[
                status
                putaway_prep_containers
                putaway_prep_inventories
                recode
                stock_processes
            ]
        ],

        custom => [
            # methods in the Result class
            qw[
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
