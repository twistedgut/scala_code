#!/usr/bin/perl
use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::Data;
use SchemaTest;

use Test::XTracker::RunCondition dc => ['DC1','DC2'];

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::PackagingAttribute',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                packaging_type_id
                name
                public_name
                title
                public_title
                channel_id
                description
            ]
        ],

        relations => [
            qw[
                channel
                packaging_type
            ]
        ],

        custom => [
            qw[
                broadcast
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
