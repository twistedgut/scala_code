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
        moniker   => 'Public::CorrespondenceTemplate',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                name
                operator_id
                access
                content
                department_id
                ordering
                subject
                content_type
                readonly
                id_for_cms
            ]
        ],

        relations => [
            qw[
                return_email_logs
                shipment_email_logs
                pre_order_email_logs
                order_email_logs
                correspondence_templates_logs
                department
            ]
        ],

        custom => [
            qw[
                render_template
                in_cms_format
                update_email_template
                get_most_recent_log_entry
            ]
        ],

        resultsets => [
            qw[
                find_by_name
            ]
        ],
    }
);

$schematest->run_tests();
