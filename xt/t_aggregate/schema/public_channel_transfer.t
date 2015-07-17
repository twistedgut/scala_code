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
        moniker   => 'Public::ChannelTransfer',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                product_id
                from_channel_id
                to_channel_id
                status_id
            ]
        ],

        relations => [
            qw[
                from_channel
                status
                to_channel
                channel_transfer_picks
                channel_transfer_putaways
                log_channel_transfers
                product
            ]
        ],

        custom => [
            qw[
                set_status
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
