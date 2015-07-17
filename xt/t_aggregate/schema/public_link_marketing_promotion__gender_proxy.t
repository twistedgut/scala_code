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
        moniker   => 'Public::LinkMarketingPromotionGenderProxy',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                marketing_promotion_id
                gender_proxy_id
                include
            ]
        ],

        relations => [
            qw[
                marketing_promotion
                gender_proxy
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                order_by_title
                get_included_titles
            ]
        ],
    }
);

$schematest->run_tests();
