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
        moniker   => 'Orders::LogPaymentValidChange',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                payment_id
                date_changed
                new_state
            ]
        ],

        relations => [
            qw[
                payment
            ]
        ],

        custom => [
            qw[
                copy_to_replaced_payment_log
            ]
        ],

        resultsets => [
            qw[
                move_to_replaced_payment_log_and_delete
            ]
        ],
    }
);

$schematest->run_tests();
