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
        moniker   => 'ACL::AuthorisationRole',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                authorisation_role
            ]
        ],

        relations => [
            qw[
                link_authorisation_role__authorisation_sub_sections
                link_authorisation_role__url_paths
                authorisation_sub_sections
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                get_main_nav_options
                get_roles_for_main_nav_option
                get_role_names_for_main_nav_option
                get_roles_for_url_path
                get_role_names_for_url_path
                get_all_roles
                get_main_nav_options_for_ui
            ]
        ],
    }
);

$schematest->run_tests();
