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
        moniker   => 'Public::LocalExchangeRate',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                country_id
                rate
                start_date
                end_date
            ]
        ],

        relations => [
            qw[
                country
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                get_rates
                set_new_rate
            ]
        ],
    }
);

$schematest->run_tests();
