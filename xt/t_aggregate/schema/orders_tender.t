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
        moniker   => 'Orders::Tender',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                order_id
                voucher_code_id
                rank
                value
                type_id
                last_updated
            ]
        ],

        relations => [
            qw[
                order
                voucher_instance
                type
                renumeration_tenders
                renumerations
            ]
        ],

        custom => [
            qw[
                remaining_value
                voucher_code
            ]
        ],

        resultsets => [
            qw[
                voucher_usage
                sourceless_vouchers
            ]
        ],
    }
);

$schematest->run_tests();
