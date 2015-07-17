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
        moniker   => 'Public::ReturnArrival',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                return_airway_bill
                date
                dhl_tape_on_box
                box_damaged
                damage_description
                return_delivery_id
                operator_id
                removed
                packages
                return_removal_reason_id
                removal_notes
                goods_in_processed
                last_updated
            ]
        ],

        relations => [
            qw[
                link_return_arrival__shipments
                return_delivery
                return_removal_reason
                operator
                return_items
                return_awb_shipments
            ]
        ],

        custom => [
            qw[
                complete
                add_package
                remove_package
                shipment
            ]
        ],

        resultsets => [
            qw[
                get_returns_arrived
                find_by_awb
            ]
        ],
    }
);

$schematest->run_tests();
