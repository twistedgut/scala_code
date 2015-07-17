#!/usr/bin/perl

use NAP::policy "tt";

# load the module that provides all of the common test functionality
use FindBin::libs;
use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::PutawayPrepContainerStatus',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                status
                description
            ]
        ],

        relations => [
            # belongs_to
            # has_many
            qw[
                putaway_prep_containers
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
