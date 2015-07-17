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
        moniker   => 'ACL::LinkAuthorisationRoleURLPath',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                authorisation_role_id
                url_path_id
            ]
        ],

        relations => [
            qw[
                authorisation_role
                url_path
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
