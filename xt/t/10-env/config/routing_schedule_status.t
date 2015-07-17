#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 Checks the Routing Schedule Status Rank's are Correct

This tests that the 'rank' values on the 'routing_schedule_status' table are correct as these
values are used by the 'in_correct_sequence' method for the 'Public::RoutingSchedule' class to
read back the schedule records in the correct order.

=cut



use Data::Dump qw( pp );

use Test::XTracker::Data;

use XTracker::Constants::FromDB         qw( :routing_schedule_status );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

my %expected    = (
        $ROUTING_SCHEDULE_STATUS__SCHEDULED             => 10,
        $ROUTING_SCHEDULE_STATUS__SHIPMENT_UNDELIVERED  => 20,
        $ROUTING_SCHEDULE_STATUS__SHIPMENT_UNCOLLECTED  => 20,
        $ROUTING_SCHEDULE_STATUS__SHIPMENT_DELIVERED    => 20,
        $ROUTING_SCHEDULE_STATUS__SHIPMENT_COLLECTED    => 20,
        $ROUTING_SCHEDULE_STATUS__RE_DASH_SCHEDULED     => 30,
    );
my %got         = map { $_->id => $_->rank }
                    $schema->resultset('Public::RoutingScheduleStatus')->all;
is_deeply( \%got, \%expected, "Routing Schedule Status Rankings as Expected" );


done_testing;

#-------------------------------------------------------------------------------
