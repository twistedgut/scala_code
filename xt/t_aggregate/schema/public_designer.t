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
        moniker   => 'Public::Designer',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                designer
                url_key
            ]
        ],

        relations => [
            qw[
                designer_channel
                designer_channels
                legacy_designer_suppliers
                suppliers
                channels
                products
                link_marketing_promotion__designers
                purchase_orders
                legacy_designer_supplier
                log_designer_descriptions
                attribute_values
                log_website_states
                promotion_detail_designers
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                designer_with_dlp_list
                drop_down_options
                designer_list
                get_contents_for_field
                update_field_content
                list_for_upload_date
            ]
        ],
    }
);

$schematest->run_tests();

