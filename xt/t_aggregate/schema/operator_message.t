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
        moniker   => 'Operator::Message',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                subject
                body
                created
                recipient_id
                sender_id
                viewed
                deleted
            ]
        ],

        relations => [
            qw[
                recipient
                sender
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                message_list
                message_count
                read_message_count
                unread_message_count
            ]
        ],
    }
);

$schematest->run_tests();
