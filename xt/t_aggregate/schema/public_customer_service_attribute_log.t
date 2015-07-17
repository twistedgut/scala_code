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
        moniker   => 'Public::CustomerServiceAttributeLog',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                customer_id
                service_attribute_type_id
                last_sent
            ]
        ],

        relations => [
            qw[
                customer
                service_attribute_type
            ]
        ],

        custom => [
            qw[
            ],
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
