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
        moniker   => 'Public::Flag',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                description
                flag_type_id
            ]
        ],

        relations => [
            qw[
                customer_flags
                flag_type
                order_flags
                shipment_flags
            ]
        ],

        custom => [
            qw[
                icon_name
            ]
        ],

        resultsets => [
            qw[
                by_description
            ]
        ],
    }
);

$schematest->run_tests();

