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
        moniker   => 'ACL::LinkAuthorisationRoleAuthorisationSubSection',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                authorisation_role_id
                authorisation_sub_section_id
            ]
        ],

        relations => [
            qw[
                authorisation_role
                authorisation_sub_section
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
