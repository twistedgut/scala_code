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
        moniker   => 'Public::SmsCorrespondence',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                csm_id
                mobile_number
                message
                date_sent
                sms_correspondence_status_id
                failure_code
            ]
        ],

        relations => [
            qw[
                csm
                sms_correspondence_status
                link_sms_correspondence__returns
                link_sms_correspondence__shipments
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
