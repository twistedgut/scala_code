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
        moniker   => 'Public::ShipmentStatusLog',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                date
                shipment_id
                shipment_status_id
                operator_id
            ]
        ],

        relations => [
            qw[
                operator
                shipment
                status
                shipment_hold_logs
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
