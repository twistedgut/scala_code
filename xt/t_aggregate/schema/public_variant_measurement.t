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
        moniker   => 'Public::VariantMeasurement',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                variant_id
                measurement_id
                value
            ]
        ],

        relations => [
            qw[
                variant
                measurement
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                get_variant_measurement_value
            ]
        ],
    }
);

$schematest->run_tests();
