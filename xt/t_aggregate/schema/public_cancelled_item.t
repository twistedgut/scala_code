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
        moniker   => 'Public::CancelledItem',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                shipment_item_id
                customer_issue_type_id
                date
            ]
        ],

        relations => [
            qw[
                customer_issue_type
                shipment_item
            ]
        ],

        custom => [
            qw[
                notes
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
