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
        moniker   => 'Public::StockTransfer',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                date
                type_id
                status_id
                variant_id
                channel_id
                info
            ]
        ],

        relations => [
            qw[
                link_stock_transfer__shipments
                channel
                status
                type
                variant
                shipments
            ]
        ],

        custom => [
            qw[
                is_cancelled
                set_cancelled
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
