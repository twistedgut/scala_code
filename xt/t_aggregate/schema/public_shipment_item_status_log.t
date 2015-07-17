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
        moniker   => 'Public::ShipmentItemStatusLog',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                shipment_item_id
                shipment_item_status_id
                operator_id
                date
                packing_exception_action_id
            ]
        ],

        relations => [
            qw[
                shipment_item_status
                shipment_item
                operator
                packing_exception_action
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                filter_no_virtual_vouchers
                filter_between_dates
                filter_by_item_status
                filter_by_customer_shipments
                filter_by_sample_shipments
                filter_by_customer_channel
                filter_by_sample_channel
                filter_for_report
            ]
        ],
    }
);

use Test::Exception;
use Test::More;
TODO: {
    local $TODO = q{Test::DBIx::Class::Schema has a bug where we can't run tests against Mooseified custom resultset classes};
    lives_ok(
        sub { $schematest->run_tests() },
        'revert this commit when this gets fixed'
    );
}
done_testing;
