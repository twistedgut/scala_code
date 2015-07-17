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
        moniker   => 'SystemConfig::ConfigGroupSetting',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                config_group_id
                setting
                value
                sequence
                active
            ]
        ],

        relations => [
            qw[
                config_group
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                config_var
                config_vars_by_group
            ]
        ],
    }
);

$schematest->run_tests();
