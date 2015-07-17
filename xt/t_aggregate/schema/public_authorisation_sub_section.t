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
        moniker   => 'Public::AuthorisationSubSection',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                authorisation_section_id
                sub_section
                ord
                acl_controlled
            ]
        ],

        relations => [
            qw[
                section
                operator_authorisations
                operator_preferences
                link_authorisation_role__authorisation_sub_sections
                acl_roles
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                data_for_user_access_report
                permissions_hashref
                get_all_main_nav_options
                get_user_roles
                get_user_roles_for_ui
            ]
        ],
    }
);

$schematest->run_tests();
