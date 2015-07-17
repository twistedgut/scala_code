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
        moniker   => 'Public::OperatorAuthorisation',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                operator_id
                authorisation_sub_section_id
                authorisation_level_id
            ]
        ],

        relations => [
            qw[
                operator
                auth_sub_section
                auth_level
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                operator_has_permission
                get_auth_level_for_main_nav_option
            ]
        ],
    }
);

$schematest->run_tests();
