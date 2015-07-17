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
        moniker   => 'Public::ShipmentBoxLog',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                shipment_box_id
                skus
                action
                operator_id
                timestamp
            ]
        ],

        relations => [
            qw[
                shipment_box
                operator
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
