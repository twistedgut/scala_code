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
        moniker   => 'SystemConfig::ConfigGroup',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                name
                channel_id
                active
            ]
        ],

        relations => [
            qw[
                config_group_settings
                channel
            ]
        ],

        custom => [
            qw[
                setting
                setting_value
                staff_sla_interval
                exchange_creation_sla_interval
            ]
        ],

        resultsets => [
            qw[
                get_groups
            ]
        ],
    }
);

$schematest->run_tests();
