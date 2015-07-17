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
        moniker   => 'Public::CorrespondenceSubjectMethod',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                correspondence_subject_id
                correspondence_method_id
                can_opt_out
                default_can_use
                enabled
                notify_on_failure
                send_from
                copy_to_crm
            ]
        ],

        relations => [
            qw[
                correspondence_subject
                correspondence_method
                customer_csm_preferences
                orders_csm_preferences
                csm_exclusion_calendars
                sms_correspondences
            ]
        ],

        custom => [
            qw[
                channel
                email_for_failure_notification
                window_open_to_send
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
