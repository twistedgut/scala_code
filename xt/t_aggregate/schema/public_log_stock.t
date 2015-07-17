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
        moniker   => 'Public::LogStock',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                variant_id
                stock_action_id
                operator_id
                notes
                quantity
                balance
                date
                channel_id
            ]
        ],

        relations => [
            qw[
                channel
                product_variant
                voucher_variant
                operator
            ]
        ],

        custom => [
            qw[
                variant
            ]
        ],

        resultsets => [
            qw[
                log
            ]
        ],
    }
);

$schematest->run_tests();
