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
        moniker   => 'Public::PreOrderPayment',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                pre_order_id
                psp_ref
                preauth_ref
                settle_ref
                fulfilled
                valid
            ]
        ],

        relations => [
            qw[
                pre_order
            ]
        ],

        custom => [
            qw[
                psp_refund_the_amount
                payment_method_rec
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
