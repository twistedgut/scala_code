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
        moniker   => 'Public::Business',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                name
                config_section
                url
                show_sale_products
                email_signoff
                email_valediction
                fulfilment_only
                client_id
            ]
        ],

        relations => [
            qw[
                channels
                third_party_skus
                client
            ]
        ],

        custom => [
            qw[
                short_name
                branded_date
                branded_salutation
                is_nap
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
