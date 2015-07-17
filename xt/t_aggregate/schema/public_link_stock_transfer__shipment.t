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
        moniker   => 'Public::LinkStockTransferShipment',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                stock_transfer_id
                shipment_id
            ]
        ],

        relations => [
            qw[
                shipment
                stock_transfer
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
