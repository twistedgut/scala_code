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
        moniker   => 'Public::LogWelcomePackChange',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                welcome_pack_change_id
                affected_id
                value
                operator_id
                date
            ]
        ],
        relations => [
            qw[
                operator
                welcome_pack_change
            ]
        ],
        custom => [
            qw[
                affected
                channel
                description
                change_value
            ]
        ],
        resultsets => [
            qw[
                get_config_setting_changes
                get_config_group_changes
                get_config_changes
                for_page

                order_by_id
                order_by_date
                order_by_date_id
                order_by_id_desc
                order_by_date_desc
                order_by_date_id_desc
            ]
        ],
    }
);

$schematest->run_tests();

