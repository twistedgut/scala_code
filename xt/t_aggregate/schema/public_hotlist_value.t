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
        moniker   => 'Public::HotlistValue',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                hotlist_field_id
                value
                channel_id
                order_nr
            ]
        ],

        relations => [
            qw[
                hotlist_field
                channel
            ]
        ],

        custom => [
            qw[
                format_for_sync
            ]
        ],

        resultsets => [
            qw[
                get_all
                get_for_fraud_checking
            ]
        ],
    }
);

$schematest->run_tests();
